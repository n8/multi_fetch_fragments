Multi-fetch Fragments
===========

Multi-fetch Fragments makes rendering and caching a collection of template partials easier and faster. It takes advantage of the read_multi method on Rails cache store. Some cache implementations have an optimized version of read_multi, which includes very popular Memcache stores like Dalli. Normally partial rendering and caching for a collection only retrieves items from the cache store with the less optimized read method.

In a super simple test Rails app described below, we saw a 46% improvement for our test action. 

The action taking 168 ms per request on average (using apache bench) was improved to 90 ms. Application timeouts were also decreased from 1% of requests to 0%.

## Syntax

If you want to automatically cache each partial rendered as a collection and have them fetched back from Memcache with read_multi: 

```
<%= render partial: 'item', collection: @items, cache: true %>
```

If you want a custom cache key for this same behavior, use a Proc: 

```
<%= render partial: 'item', collection: @items, cache: Proc.new{|item| [item, 'show']} %>
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

Using [Blitz.io](http://blitz.io) I ran a test ramping up to 25 simultaneous users against the test app hosted on heroku. We configured heroku to use 10 dynos and unicorn with 3 workers on each dyno.


#### without_gem

This rush generated 648 successful hits in 1.0 min and we transferred 24.49 MB of data in and out of your app. The average hit rate of 10/second translates to about 892,683 hits/day.

The average response time was 168 ms.

You've got bigger problems, though: 1.07% of the users during this rush experienced timeouts or errors!

#### with_gem

This rush generated 705 successful hits in 1.0 min and we transferred 24.08 MB of data in and out of your app. The average hit rate of 11/second translates to about 969,892 hits/day.

The average response time was 90 ms.


Installation
------------

1. Add `gem 'multi_fetch_fragments'` to your Gemfile.
2. Run `bundle install`.
3. Restart your server 
4. Render collection of objects with their partial using the new syntax (see above): 

```
<%= render partial: 'item', collection: @items, cache: true %>
```

Note: You may need to refactor any partials that contain cache blocks. For example if you have an _item.html.erb partial with a cache block inside caching the item, you can remove the method call to "cache" and rely on the new render method abilities.


Feedback
--------

Feedback and pull requests are greatly appreciated. Let me know if I can improve this.

