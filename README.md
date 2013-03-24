Multi-fetch Fragments
===========

> I just implemented this on the staging environment of [https://www.biglittlepond.com](https://www.biglittlepond.com). The one-line `render` call for the most recently collected items dropped from ~700 ms to ~50 ms. 25 items per page. This will be going into the production release later this week.

>  [Nathaniel Jones](http://twitter.com/thenthj)


Multi-fetch Fragments makes rendering and caching a collection of template partials easier and faster. It takes advantage of the read_multi method on the Rails cache store. Some cache implementations have an optimized version of read_multi, which includes the popular Dalli client to Memcached. Traditionally, partial rendering and caching of a collection occurs sequentially, retrieving items from the cache store with the less optimized read method.

In a super simple test Rails app described below, I saw a 46-78% improvement for the test action.

According to New Relic the test action went from an average of 152 ms to 34 ms. Blitz.io, had their reports showing a test action taking an average of 168 ms per request improving to 90 ms. Application timeouts also decreased from 1% of requests to 0%.

The ideal user of this gem is someone who's rendering and caching a large collection of the same partial. (e.g. Todo lists, rows in a table)

<hr/>

## Syntax

Using this gem, if you want to automatically render a collection and cache each partial with its default cache key:

```erb
<%= render partial: 'item', collection: @items, cache: true %>
```
Short-hand rendering of partials is also supported:

```erb
<%= render @items, cache: true %>
```

If you want a custom cache key for this same behavior, use a Proc or lambda (or any object that responds to call):

```erb
<%= render partial: 'item', collection: @items, cache: Proc.new{|item| [item, 'show']} %>
```

Note: `cache: false` also disables the cached rendering.


## Background

One of the applications I worked on at the Obama campaign was Dashboard, a virtual field office we created. Dashboard doesn't talk directly to a database. It only speaks to a rest API called Narwhal. You can imagine the performance obstacles we faced building an application this way. So we had to take insane advantage of caching everything we could. This included looking for as many places as possible where we could fetch from Memcached in parallel using Rails' read_multi:

> <b>read_multi(*names)</b> public

> Read multiple values at once from the cache. Options can be passed in the last argument.

> Some cache implementation may optimize this method.

> Returns a hash mapping the names provided to the values found.

The result of all this is I'm constantly on the lookout for more places where caching can be optimized. And one area I've noticed recently is how us Rails developers render and cache collections of partials.

For example, at Inkling we render a client homepage as a collection of divs:

```erb
<%= render partial: 'markets/market', collection: @markets %>
```

And each _market.html.erb partial is cached. If you looked inside you'd see something like:

```erb
<% cache(market) do %>
slow things....
<% end %>
```

It's tough to cache the entire collection of these partials in a single parent, because each user sees a different homepage depending on their permissions. But even if we could cache the entire page for lots of users, that parent cache would be invalidated each time one of its children changes, which they do, frequently.

So for a long time I've dealt with the performance of rendering out pages where we read from Memcached dozens and dozens of times, sequentially. Memcached is fast, but fetching from Memcached like this can add up, especially over a cloud like Heroku.

Luckily, Memcached supports reading a bunch of things at one time. So I've tweaked the render method of Rails to utilize fetching multiple things at once.

How much faster?
-----------------------------

Depends on how many things your fetching from Memcached for a single page. But I tested with [a simple application that renders 50 items to a page](https://github.com/n8/multi_fetch_fragments_test_app). Each of those items is a rendered partial that gets cached to Memcached.

There's two actions: without_gem and with_gem. without_gem performs caching around each individual fragment as it's rendered sequentially. with_gem uses the new ability this gem gives to the render partial method.

Using [Blitz.io](http://blitz.io) I ran a test ramping up to 25 simultaneous users against the test app hosted on Heroku. I configured Heroku to use 10 dynos and unicorn with 3 workers on each dyno.

#### without_gem

This rush generated 648 successful hits in 1.0 min and we transferred 24.49 MB of data in and out of your app. The average hit rate of 10/second translates to about 892,683 hits/day.

The average response time was 168 ms.

You've got bigger problems, though: 1.07% of the users during this rush experienced timeouts or errors!

#### with_gem

This rush generated 705 successful hits in 1.0 min and we transferred 24.08 MB of data in and out of your app. The average hit rate of 11/second translates to about 969,892 hits/day.

The average response time was 90 ms.

New Relic's report was even more rosy. According to New Relic, the test action went from an average of 152 ms to 34 ms.

Installation
------------

1. Add `gem 'multi_fetch_fragments'` to your Gemfile.
2. Run `bundle install`.
3. Restart your server
4. Render collection of objects with their partial using the new syntax (see above):

```erb
<%= render partial: 'item', collection: @items, cache: true %>
```

Note: You may need to refactor any partials that contain cache blocks. For example if you have an _item.html.erb partial with a cache block inside caching the item, you can remove the method call to "cache" and rely on the new render method abilities.

Feedback
--------
[Source code available on Github](https://github.com/n8/multi_fetch_fragments). Feedback and pull requests are greatly appreciated.  Let me know if I can improve this.

Credit
--------
A ton of thanks to the folks at the tech team for the Obama campaign for inspiring this. Especially Jesse Kriss ([@jkriss](http://github.com/jkriss)) and Chris Gansen ([@cgansen](http://github.com/cgansen)) who really lit the path on Dashboard and our optimizations there. Huge thanks too to the folks testing and fixing early versions: Christopher Manning ([@christophermanning](http://github.com/christophermanning)), Nathaniel Jones ([@nthj](http://github.com/nthj)), and Tom Fakes ([@tomfakes](http://github.com/tomfakes)).

