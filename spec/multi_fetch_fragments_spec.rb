require 'spec_helper'

describe MultiFetchFragments do
  it "doesn't smoke" do
    MultiFetchFragments::Railtie.run_initializers

    view = ActionView::Base.new([File.dirname(__FILE__)], {})
    view.render(:partial => "views/customer", :collection => [ Customer.new("david"), Customer.new("mary") ]).should == "Hello: david\nHello: mary\n"
  end

  it "works for passing in a custom key" do
    cache_mock = mock()
    RAILS_CACHE = cache_mock
    MultiFetchFragments::Railtie.run_initializers

    controller = ActionController::Base.new
    view = ActionView::Base.new([File.dirname(__FILE__)], {}, controller)

    customer = Customer.new("david")
    key = controller.fragment_cache_key([customer, 'key'])
    
    cache_mock.should_receive(:read_multi).with([key]).and_return({key => 'Hello'})

    view.render(:partial => "views/customer", :collection => [ customer ], :cache => Proc.new{ |item| [item, 'key']}).should == "Hello"
  end
end
