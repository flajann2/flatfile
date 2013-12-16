require 'spec_helper'

describe FlatFile do
  context "Class level" do
    before(:each) do
      class FooMapper
        include FlatFile
        flat do |a|
          a.line :header do |l|
            l.field :PLANNER, 20, :order, "<def>" do |m| m[:plan] end
            l.field :ORIGINATOR, 30, :parts, nil do |p| p[:orig] end
          end

          a.line :repeaters, looping: :rep do |l|
            l.condition :lob do |r| r[:notme].nil? end
            l.condition :lob do |r| true end
            l.field :LINES, 7, :rep, "NP" do |r| r[:one] end
            l.field :LINES, 7, :rep, "NP" do |r| r[:two] end
            l.field :ORIGINATOR, 30, :parts, nil do |p| p[:orig] end           
          end
        end       
      end
    end

    it "Renders the result" do
      fm = FooMapper.new
      fm.<< order: {plan: "Go forth and do"}, parts: {orig: "Original"}
      fm.render.should == "Go forth and do     Original                      \n"
    end

    it "Handles a missing source object" do
      fm = FooMapper.new
      fm.<< order: {plan: "Go down and do"} 
      fm.render.should == "Go down and do                                    \n"
    end

    it "Handles looping constructs" do
      fm = FooMapper.new
      fm.<< order: {plan: "Order Plan"}
      fm.<< rep: [{one: "00-one", two: "00-two"}, 
                  {one: "01-one", two: "01-two"}, 
                  {one: "02-one", two: "02-two"},
                  {one: "03-one", two: "03-two", notme: true}
                 ]
      fm.<< parts: {orig: "Orig Part"}
      fm.render.should == "Order Plan          Orig Part                     \n00-one 00-two Orig Part                     \n01-one 01-two Orig Part                     \n02-one 02-two Orig Part                     \n"
    end

  end
end
