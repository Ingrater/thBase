module thBase.task;

import thBase.container.vector;
import thBase.container.stack;
import thBase.container.hashmap;
import core.sync.mutex;
import core.thread;
import core.atomic;
import thBase.ctfe;
import thBase.traits;
import std.random;
import thBase.allocator;

__gshared Vector!TaskQueue g_taskQueues;
__gshared Mutex g_taskMutex;
__gshared Mutex g_taskQueueDeleteMutex;

shared static this()
{
  assert(g_taskQueues is null);
  g_taskQueues = New!(typeof(g_taskQueues));
  g_taskMutex = New!(typeof(g_taskMutex));
  g_taskQueueDeleteMutex = New!(typeof(g_taskQueueDeleteMutex));
}

shared static ~this()
{
  Delete(g_taskQueues); g_taskQueues = null;
  Delete(g_taskMutex); g_taskMutex = null;
  Delete(g_taskQueueDeleteMutex); g_taskQueueDeleteMutex = null;
}

static this()
{
  g_localTaskQueue = New!TaskQueue();
}

static ~this()
{
  Delete(g_localTaskQueue);
}

void spawn(Task task)
{
  g_localTaskQueue.addTask(task);
}

static TaskQueue g_localTaskQueue;

class TaskQueue
{
  private:
    composite!Mutex m_queueMutex;
    composite!(Vector!Task) m_taskQueue;
    composite!(Vector!TaskWorker) m_waitingWorkers;
    composite!(Stack!TaskWorker) m_freeWorkers;
    TaskWorker m_currentWorker;
    Random gen;

  public:
    this()
    {
      m_queueMutex = typeof(m_queueMutex)(DefaultCtor());
      m_queueMutex.construct();
      m_taskQueue = typeof(m_taskQueue)(DefaultCtor());
      m_taskQueue.construct();
      m_waitingWorkers = typeof(m_waitingWorkers)(DefaultCtor());
      m_waitingWorkers.construct();
      m_freeWorkers = typeof(m_freeWorkers)(DefaultCtor());
      m_freeWorkers.construct();

      {
        g_taskMutex.lock();
        scope(exit) g_taskMutex.unlock();
        g_taskQueues ~= this;
      }
    }

    ~this()
    {
      {
        g_taskMutex.lock();
        scope(exit) g_taskMutex.unlock();

        g_taskQueues.remove(this);
      }
    }

    final void addTask(Task task)
    {
      uint newCount = atomicOp!"+="(*task.m_identifier.spawnCount, 1);
      assert(newCount > 0 , "invalid task spawn count");

      m_queueMutex.lock();
      scope(exit) m_queueMutex.unlock();
      
      m_taskQueue ~= task;
    }

    final void yieldCurrentTaskUntil(bool delegate() condition)
    {
      assert(m_currentWorker !is null);
      {
        m_queueMutex.lock();
        scope(exit) m_queueMutex.unlock();

        m_waitingWorkers ~= m_currentWorker;
      }
      m_currentWorker.canExecute = condition;
      m_currentWorker.yield();
    }

    private TaskWorker findNextWorker()
    {
      m_queueMutex.lock();
      scope(exit) m_queueMutex.unlock();

      //first check if there are any waiting workers ready
      TaskWorker result = null;
      foreach(worker; m_waitingWorkers)
      {
        //the current worker might just yielded so skip
        if(worker is m_currentWorker)
          continue;
        if(worker.canExecute())
        {
          result = worker;
          break;
        }
      }
      if(result !is null)
      {
        m_waitingWorkers.remove(result);
        return result;
      }

      //then check the task list
      if(m_taskQueue.length == 0)
      {
        bool stealingSuccessfull = false;
        //try stealing tasks
        //We can not allow any task queues to be deleted while we try to steal tasks
        {
          g_taskQueueDeleteMutex.lock();
          scope(exit) g_taskQueueDeleteMutex.unlock();

          //Make a copy of the TaskWorker array so we don't have to block the whole time
          TaskQueue[] allTaskQueues;
          {
            g_taskMutex.lock();
            scope(exit) g_taskMutex.unlock();

            allTaskQueues = AllocatorNewArray!TaskQueue(ThreadLocalStackAllocator.globalInstance, g_taskQueues.length);
            allTaskQueues[] = g_taskQueues.toArray();
          }
          scope(exit) AllocatorDelete(ThreadLocalStackAllocator.globalInstance, allTaskQueues);

          //TODO start stealing from a random task queue, not always from the first one

          size_t startIndex = uniform(0, allTaskQueues.length);
          immutable size_t numTasks = allTaskQueues.length;
          for(size_t i=0; i<numTasks; i++)
          {
            auto stealFrom = allTaskQueues[(i + startIndex) % numTasks];
            if(stealFrom is this)
              continue;
            
            //prevent modifications on the task queue we try to steal from
            //also we use tryLock here to prevent deadlocks in case A steals from B and B steals from A
            if( stealFrom.m_queueMutex.tryLock() )
            {
              scope(exit) stealFrom.m_queueMutex.unlock();

              //First find waiting and ready workers
              uint numWaitingAndReady = 0;
              TaskWorker[16] waitingAndReady;
              foreach(worker; stealFrom.m_waitingWorkers)
              {
                if(worker.task.canBeMovedToOtherThreads && worker.canExecute())
                {
                  waitingAndReady[numWaitingAndReady++] = worker;
                }
              }
              if(numWaitingAndReady >= waitingAndReady.length)
                numWaitingAndReady = cast(uint)(waitingAndReady.length-1);
              if(numWaitingAndReady > 0)
              {
                numWaitingAndReady = (numWaitingAndReady / 2) > 0 ? numWaitingAndReady / 2 : 1;
                result = waitingAndReady[0];
                stealFrom.m_waitingWorkers.remove(result);
                foreach(worker; waitingAndReady[1..numWaitingAndReady])
                {
                  m_waitingWorkers ~= worker;
                  stealFrom.m_waitingWorkers.remove(worker);
                }
                stealingSuccessfull = true;
              }

              //Now steal tasks
              if(stealFrom.m_taskQueue.length > 0)
              {
                size_t end = stealFrom.m_taskQueue.length;
                size_t begin = end / 2;
                
                m_taskQueue ~= stealFrom.m_taskQueue[begin..end];
                stealFrom.m_taskQueue.resize(begin);
                stealingSuccessfull = true;
              }

              if(stealingSuccessfull)
                break;
            }
          }
        }
        if(!stealingSuccessfull)
          return null;
      }
      auto task = m_taskQueue[0];
      m_taskQueue.remove(task);

      //do we have a free worker?
      if(m_freeWorkers.size() > 0)
      {
        result = m_freeWorkers.pop();
        result.task = task;
        result.resetWorker();
      }
      else
      {
        //We have to create a new worker
        result = New!TaskWorker();
        result.task = task;
      }
      return result;
    }

    /**
     * Executes tasks, stops if there are no more tasks
     * Params:
     *   max = maximum number of tasks to execute before return, 0 means infinite
     * Returns:
     *   the number of tasks executed
     */
    final uint executeTasks(uint max = 0)
    {
      uint i=0;
      for(; max == 0 || i < max; i++)
      {
        if(!executeOneTask())
          break;
      }
      return i;
    }

    /**
     * executes one task and then returns
     * Returns: True if one task was executed, false if there are no more tasks
     */
    final bool executeOneTask()
    {
      m_currentWorker = findNextWorker();
      if(m_currentWorker is null)
        return false;
      m_currentWorker.call();

      //check if the worker terminated, if yes add him to the free list
      if(m_currentWorker.state == Fiber.State.TERM)
      {
        {
          m_queueMutex.lock();
          scope(exit) m_queueMutex.unlock();

          m_freeWorkers.push(m_currentWorker);
        }
        m_currentWorker = null;
      }
      return true;
    }

    /**
     * Executes tasks until the condition is met. If there are no more tasks to execute it will wait for the condition to become true anyway
     */
    void executeTasksUntil(scope bool delegate() condition)
    {
      do
      {
        if(!executeOneTask())
          Thread.sleep(dur!"msecs"(1));
      }
      while(condition());
    }
}

/**
 * A task worker, is a worker which can execute a single task and may be clieded at any point from within the task
 */
class TaskWorker : Fiber
{
  enum TASK_WORKER_STACK_SIZE = 1024 * 1024 * 1; //1 MB
  private:
    final void executeTask()
    {
      task.Execute();

      //after Execute() returned the task is finished
      uint newCount = atomicOp!"-="(*task.m_identifier.spawnCount, 1);
      if(newCount == 0)
      {
        task.OnTaskFinished();
      }
    }

    final bool defaultCondition()
    {
      return true;
    }

  public:
    /**
     * the task that is currently beeing executed
     */
    Task task;
    
    /**
     * if the worker can execute or if it is currently blocked
     */
    bool delegate() canExecute;
    
    /**
     * constructor
     */
    this()
    {
      canExecute = &defaultCondition;
      super(&executeTask);
    }

    /**
     * resets the worker to the intal execution state
     */
    final void resetWorker()
    {
      assert(state == State.TERM, "can not reset worker which is not terminated");
      reset(&executeTask);
      canExecute = &defaultCondition;
    }
}

/**
 * A identifier which gives a task a unique name. 
 * Tasks that are able to be executed multiple times should share the same identifier.
 */
struct TaskIdentifier
{
  uint hash;
  shared(uint*) spawnCount;

  uint Hash() { return hash; }

  debug
  {
    __gshared Hashmap!(uint, string) m_identifierList;

    shared static this()
    {
      m_identifierList = New!(typeof(m_identifierList))();
    }

    shared static ~this()
    {
      Delete(m_identifierList);
      m_identifierList = null;
    }
  }

  static TaskIdentifier Create(string name)()
  {
    __gshared immutable uint hash = FNVHash(name);
    __gshared uint spawnCount = 0;

    debug
    {
      synchronized(m_identifierList)
      {
        if(m_identifierList.exists(hash))
        {
          assert(m_identifierList[hash] == name, "TaskIdentifier hash collision with new identifier " ~ name);
        }
        else
        {
          m_identifierList[hash] = name;
        }
      }
    }

    return TaskIdentifier(hash, cast(shared(uint*))&spawnCount);
  }

  /**
   * returns true if this task identifier is valid, false otherwise
   */
  @property isValid()
  {
    return spawnCount !is null;
  }

  /**
   * returns true if there are no more spawned instances of this task that are not finished yet, false otherwise
   */
  @property bool allFinished()
  {
    return (atomicLoad(*spawnCount) == 0);
  }
}

unittest
{
  auto identifier = TaskIdentifier.Create!"TestIdentifier"();
}

/**
 * A unit of work that can be executed in paralell with other units of work.
 * It may be executed on any thread currently ready for execution.
 * Switching threads during execution is optional though. If the task should be moveable to other threads
 * during execution special attention to thread local memory has to be paid
 */
abstract class Task
{
  private:
    TaskIdentifier m_identifier;

  public:
    /**
     * If this task can be moved to other threads during execution or not. During execution means at any yield point
     */
    bool canBeMovedToOtherThreads = false; 

    /**
     * Constructor
     * Params:
     *   identifier = the identifier for this task
     */
    this(TaskIdentifier identifier)
    in
    {
      assert(identifier.isValid());
    }
    body
    {
      m_identifier = identifier;
    }

    /**
     * Called when the task should execute
     */
    abstract void Execute();
    
    /**
     * Called when all tasks with the same identifier as this one finished executing.
     * This function is garantueed to be only called once for the last task to finish
     */
    abstract void OnTaskFinished();
}