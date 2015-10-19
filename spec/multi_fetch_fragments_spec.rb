require 'spec_helper'

describe MultiFetchFragments do
  it "doesn't smoke" do
    MultiFetchFragments::Railtie.run_initializers

    view = ActionView::Base.new([File.dirname(__FILE__)], {})
    view.render(:partial => "views/customer", :collection => [ Customer.new("david"), Customer.new("mary") ]).should == "Hello: david\nHello: mary\n"
  end

  context "use of procs" do
    let(:item) { double(:something) }
    let(:collection) { [item] }

    it "allows the use of a procs" do
      MultiFetchFragments::Railtie.run_initializers
      view = ActionView::Base.new([File.dirname(__FILE__)], {})
      expect(collection).to receive(:foobar).with(1)
      view.render(partial: "views/counter",
                  proc: Proc.new { |collection| collection.foobar(1) },
                  collection: collection,
                  as: :customer
                 )
    end
  end

  context "variant_counter" do
    it "does not break existing functionality" do
      MultiFetchFragments::Railtie.run_initializers

      view = ActionView::Base.new([File.dirname(__FILE__)], {})
      view.render(:partial => "views/counter", :collection => [ Customer.new("david"), Customer.new("mary") ], :as => :customer).should == "Count: 0\nCount: 1\n"
    end

    it "works for the cached version" do
      cache_mock = double()
      MultiFetchFragments::Railtie.run_initializers

      controller = ActionController::Base.new
      controller.cache_store = cache_mock
      view = ActionView::Base.new([File.dirname(__FILE__)], {}, controller)

      david = Customer.new("david")
      key1 = controller.fragment_cache_key([david, 'key'])

      mary = Customer.new("mary")
      key2 = controller.fragment_cache_key([mary, 'key'])

      simon = Customer.new("simon")
      key3 = controller.fragment_cache_key([simon, 'key'])

      cache_mock.should_receive(:read_multi).with(key1, key2, key3).and_return({key1 => "Count: 0, CacheSafeCount: 0\n"})
      cache_mock.should_receive(:write).twice

      view.render(:partial => "views/cache_safe_counter", :collection => [ david, mary, simon ], :cache => Proc.new{ |item| [item, 'key']}, :as => :customer).should == "Count: 0, CacheSafeCount: 0\nCount: 0, CacheSafeCount: 1\nCount: 1, CacheSafeCount: 2\n"
    end
  end

  it "works for passing in a custom key" do
    cache_mock = double()
    MultiFetchFragments::Railtie.run_initializers

    controller = ActionController::Base.new
    controller.cache_store = cache_mock
    view = ActionView::Base.new([File.dirname(__FILE__)], {}, controller)

    customer = Customer.new("david")
    key = controller.fragment_cache_key([customer, 'key'])

    cache_mock.should_receive(:read_multi).with(key).and_return({key => 'Hello'})

    view.render(:partial => "views/customer", :collection => [ customer ], :cache => Proc.new{ |item| [item, 'key']}).should == "Hello"
  end
end
