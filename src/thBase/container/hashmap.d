module thBase.hashmap;

public import core.hashmap;

version(unittest)
{
  import thBase.conv;
  import thBase.policies.hashing;
}

unittest
{
  static struct Test
  {
    int check = 5;
    int value = 0;

    this(int value)
    {
      this.value = value;
    }

    ~this()
    {
      assert(check == 5);
    }
  }
  //test string -> test struct
  auto map1 = New!(Hashmap!(string, Test, StringHashPolicy))();
  scope(exit) Delete(map1);

  map1["1"] = Test(1);
  map1["2"] = Test(2);
  map1["3"] = Test(3);
  map1["4"] = Test(4);
  map1["5"] = Test(5);

  assert(map1.exists("1"));
  assert(map1.exists("2"));
  assert(map1.exists("3"));
  assert(map1.exists("4"));
  assert(map1.exists("5"));

  assert(map1["1"].value == 1);
  assert(map1["2"].value == 2);
  assert(map1["3"].value == 3);
  assert(map1["4"].value == 4);
  assert(map1["5"].value == 5);

  assert(map1.count == 5);

  auto result = map1.remove("1");
  assert(result);

  assert(map1.count == 4);

  assert(!map1.exists("1"));
  assert(map1.exists("2"));
  assert(map1.exists("3"));
  assert(map1.exists("4"));
  assert(map1.exists("5"));

  //test foreach(value; hashmap)
  foreach(ref Test t; map1)
  {
    assert(t.value >= 2 && t.value <= 5);
  }

  //test foreach(key, value; hashmap)
  foreach(string key, ref Test value; map1)
  {
    int val;
    auto result2 = to!int(key, val);
    assert(result2 == thResult.SUCCESS);
    assert(value.value == val);
  }

  //test keyRange
  int sum = 0;
  foreach(key; map1.keys)
  {
    int val;
    auto result2 = to!int(key, val);
    assert(result2 == thResult.SUCCESS);
    sum += val;
  }
  assert(sum == 14);

  //test valueRange
  sum = 0;
  foreach(value; map1.values)
  {
    sum += value.value;
  }
  assert(sum == 14);

  static struct Collision
  {
    uint hash = 0;
    int value = 0;
    
    this(size_t hash, int value)
    {
      this.value = value;
      this.hash = hash;
    }

    uint Hash() { return hash; }
  }

  auto map2 = New!(Hashmap!(Collision, int))();
  scope(exit) Delete(map2);

  map2[Collision(0, 0)] = 0;
  map2[Collision(1, 1)] = 1;
  map2[Collision(0, 2)] = 2;
  map2[Collision(1, 3)] = 3;
  map2[Collision(1, 4)] = 4;
  map2[Collision(0, 5)] = 5;

  assert(map2[Collision(0, 0)] == 0);
  assert(map2[Collision(1, 1)] == 1);
  assert(map2[Collision(0, 2)] == 2);
  assert(map2[Collision(1, 3)] == 3);
  assert(map2[Collision(1, 4)] == 4);
  assert(map2[Collision(0, 5)] == 5);

  assert(map2.exists(Collision(0, 0)));
  assert(map2.exists(Collision(1, 1)));
  assert(map2.exists(Collision(0, 2)));
  assert(map2.exists(Collision(1, 3)));
  assert(map2.exists(Collision(1, 4)));
  assert(map2.exists(Collision(0, 5)));
  
  assert(!map2.exists(Collision(0, 1)));
  assert(!map2.exists(Collision(1, 2)));

  map2.remove(Collision(0,0));
  map2.remove(Collision(1,1));

  assert(map2[Collision(0, 2)] == 2);
  assert(map2[Collision(1, 3)] == 3);
  assert(map2[Collision(1, 4)] == 4);
  assert(map2[Collision(0, 5)] == 5);

  assert(map2.exists(Collision(0, 2)));
  assert(map2.exists(Collision(1, 3)));
  assert(map2.exists(Collision(1, 4)));
  assert(map2.exists(Collision(0, 5)));

  map2[Collision(0, 6)] = 6;
  map2[Collision(1, 7)] = 7;

  assert(map2[Collision(0, 2)] == 2);
  assert(map2[Collision(1, 3)] == 3);
  assert(map2[Collision(1, 4)] == 4);
  assert(map2[Collision(0, 5)] == 5);
  assert(map2[Collision(0, 6)] == 6);
  assert(map2[Collision(1, 7)] == 7);

  assert(map2.exists(Collision(0, 2)));
  assert(map2.exists(Collision(1, 3)));
  assert(map2.exists(Collision(1, 4)));
  assert(map2.exists(Collision(0, 5)));
  assert(map2.exists(Collision(0, 6)));
  assert(map2.exists(Collision(1, 7)));

  map2.remove(Collision(1, 4));
  map2.remove(Collision(0, 6));

  assert(map2[Collision(0, 2)] == 2);
  assert(map2[Collision(1, 3)] == 3);
  assert(map2[Collision(0, 5)] == 5);
  assert(map2[Collision(1, 7)] == 7);

  assert(map2.exists(Collision(0, 2)));
  assert(map2.exists(Collision(1, 3)));
  assert(map2.exists(Collision(0, 5)));
  assert(map2.exists(Collision(1, 7)));

  map2[Collision(0, 2)] = 3;
  map2[Collision(0, 5)] = 6;
  map2[Collision(1, 3)] = 4;

  assert(map2[Collision(0, 2)] == 3);
  assert(map2[Collision(0, 5)] == 6);
  assert(map2[Collision(1, 3)] == 4);

  auto map3 = New!(Hashmap!(rcstring, rcstring))();
  scope(exit) Delete(map3);

  map3[rcstring("one")] = rcstring("eins");
  map3[rcstring("two")] = rcstring("zwei");
  map3[rcstring("three")] = rcstring("drei");
  map3[rcstring("four")] = rcstring("vier");
  map3[rcstring("five")] = rcstring("fünf");
  map3[rcstring("six")] = rcstring("sechs");

  assert(map3.exists(rcstring("five")));
  assert(map3[rcstring("five")] == rcstring("fünf"));

  map3.remove(rcstring("five"));
  assert(map3.exists(rcstring("five")) == false);

  auto map4 = New!(Hashmap!(int, int))();
  scope(exit) Delete(map4);

  map4[0] = 1; //should be removed
  map4[1] = 3;
  map4[2] = 2; //should be removed
  map4[3] = 0; //should be removed
  map4[4] = 6; //should be removed
  map4[5] = 5;

  auto count = map4.removeWhere((ref int key,ref int value){return key % 2 == 0 || value % 2 == 0;});
  assert(count == 4);

  assert(!map4.exists(0));
  assert(map4.exists(1));
  assert(!map4.exists(2));
  assert(!map4.exists(3));
  assert(!map4.exists(4));
  assert(map4.exists(5));
}