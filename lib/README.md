Multi-fetch Fragments
===========

Multi-fetch Fragments makes rendering a collection of cached template partials easier and faster. It takes advantage of the read_multi method on Rails cache store. Some cache implementations have an optimized version of read_multi, which includes very popular Memcache stores like Dalli. 

In a super simple test Rails app described below, we saw a 42% improvement: an action taking 324.789 ms per request on average (using apache bench) was found to improved to 187.514 ms.

## Syntax

If you want to automatically cache each partial rendered as a collection and have them fetched back from Memcache with read_multi: 

```
<%= render partial: 'item', collection: @items, cache: true %>
```

If you want a custom cache key for this same behavior, use a Proc: 

```
<%= render partial: 'item', collection: @items, cache: Proc.new{|item| [item, 'nates_awesome']} %>
```

## Background

Rails makes rendering a collection of partial templates very easy: 

```
<%= render partial: 'item', collection: @items %>
```

And if you want to make this fast, Rails makes it easy to add a fragment cache block within the item partial. _item.html.erb might look like this: 

```
<% cache item %>
  <p>
    Slower things...

    <%= item.name %>

    Eat the grass jump feed me lay down in your way, sleeping in the sink siamese hairball stretching scratched climb the curtains lick lay down in your way. Feed me leap climb the curtains persian medium hair, siamese scratched sleep in the sink chuf fluffy fur sleep on your keyboard meow. Run zzz eat feed me sniff, sleep on your keyboard knock over the lamp making biscuits purr headbutt knock over the lamp. Sniff jump headbutt scottish fold sleep in the sink, attack biting chuf sunbathe eat persian give me fish. Claw kittens short hair stuck in a tree sleep on your keyboard leap, sunbathe persian jump purr. Jump on the table long hair judging you attack your ankles zzz judging you, persian stuck in a tree shed everywhere catnip. Fluffy fur eat the grass jump on the table rip the couch lay down in your way sniff, leap lay down in your way lick hiss toss the mousie. Medium hair give me fish feed me jump on the table hairball run, scottish fold climb the curtains lay down in your way lay down in your way ragdoll.
  </p>
<% end %>

```

Caching the partial like this is great, but one drawback is that Rails will fetch each cached fragment sequentially. If you have to retrieve a bunch of these to render a single page, the additional overhead of fetching a bunch of things from Memcache can add up. Imagine if there's network latency between your app server and your memcache server. 

But Rails has a method defined for its cache store to read_multi: 

> Read multiple values at once from the cache. Options can be passed in the last argument. 
Some cache implementation may optimize this method. 
Returns a hash mapping the names provided to the values found.


How much faster?
-----------------------------

Depends on how many things your fetching from Memcache for a single page. But here's a simple application that renders 50 items to a page. Each of those items is a rendered partial that gets cached to memcache. 

[https://github.com/n8/multi_fetch_fragments_test_app](https://github.com/n8/multi_fetch_fragments_test_app)

There's two actions: without_gem and with_gem. without_gem performs caching around each individual fragment as it's rendered sequentially. with_gem uses the new ability this gem gives to the render partial method. 

Here's an ab test performed on this app running on Heroku with a single dyno and using the free memcache server. 

It was ~42% faster.


#### without_gem

```
ab -n 100 -c 1 ....herokuapp.com/without_gem

Server Software:        WEBrick/1.3.1

Document Path:          /without_gem
Document Length:        52688 bytes

Concurrency Level:      1
Time taken for tests:   32.479 seconds
Complete requests:      100
Failed requests:        29
   (Connect: 0, Receive: 0, Length: 29, Exceptions: 0)
Write errors:           0
Total transferred:      5337860 bytes
HTML transferred:       5268960 bytes
Requests per second:    3.08 [#/sec] (mean)
Time per request:       324.789 [ms] (mean)
Time per request:       324.789 [ms] (mean, across all concurrent requests)
Transfer rate:          160.50 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:       98  107   8.0    106     153
Processing:   103  217 103.0    185     659
Waiting:       30  148 111.6    111     648
Total:        242  324 102.6    291     765

Percentage of the requests served within a certain time (ms)
  50%    291
  66%    309
  75%    326
  80%    340
  90%    439
  95%    627
  98%    756
  99%    765
 100%    765 (longest request)
```

#### with_gem

```
ab -n 100 -c 1 ....herokuapp.com/with_gem

Server Software:        WEBrick/1.3.1

Document Path:          /with_gem
Document Length:        52536 bytes

Concurrency Level:      1
Time taken for tests:   18.751 seconds
Complete requests:      100
Failed requests:        62
   (Connect: 0, Receive: 0, Length: 62, Exceptions: 0)
Write errors:           0
Total transferred:      5322680 bytes
HTML transferred:       5253780 bytes
Requests per second:    5.33 [#/sec] (mean)
Time per request:       187.514 [ms] (mean)
Time per request:       187.514 [ms] (mean, across all concurrent requests)
Transfer rate:          277.20 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        1    2   0.5      2       4
Processing:   143  186  62.5    166     589
Waiting:       69  113  72.7     89     577
Total:        145  187  62.5    168     590

Percentage of the requests served within a certain time (ms)
  50%    168
  66%    182
  75%    193
  80%    205
  90%    235
  95%    313
  98%    422
  99%    590
 100%    590 (longest request)

```


Installation
------------

1. Add `gem 'multi_fetch_fragments'` to your Gemfile.
2. Run `bundle install`.
3. Restart your server 
4. Render collection of objects with their partial using the new syntax (see above): 

```
<%= render partial: 'item', collection: @items, cache: true %>
```

Make sure to remove the cache block you might be using in the item partial in this case to individual cache the fragment.

