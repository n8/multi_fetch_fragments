require 'spec_helper'

describe MultiFetchFragments do
  it "doesn't smoke" do
    MultiFetchFragments::Railtie.run_initializers

    view = ActionView::Base.new([File.dirname(__FILE__)], {})
    view.render(:partial => "views/customer", :collection => [ Customer.new("david"), Customer.new("mary") ]).should == "Hello: david\nHello: mary\n"
  end
end
