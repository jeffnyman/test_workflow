require "spec_helper"

class AmazonSearch
end

class AmazonProduct
end

class AmazonCart
end

class ExampleWorkflow
  include TestWorkflow

  attr_accessor :current_context

  def on(caller)
    caller.new
  end

  def visit(caller)
    definition = caller.new
    definition.visit
    definition
  end
end

def mock_workflow_usage
  ExampleWorkflow.paths = {
      :default => [
          [AmazonSearch, :search_for, "Star Wars"],
          [AmazonProduct, :add_to_cart, "Vector Prime"],
          [AmazonCart, :checkout]
      ],

      :trekking => [
          [AmazonSearch, :search_for, "Star Trek"],
          [AmazonProduct, :add_to_cart, "Engines of Destiny"],
          [AmazonCart, :checkout]
      ]
  }

  amazon_search = AmazonSearch.new
  allow(AmazonSearch).to receive(:new).and_return(amazon_search)
  allow(amazon_search).to receive(:respond_to?).with(:visit).and_return(true)
  allow(amazon_search).to receive(:respond_to?).with(:search_for).and_return(true)

  amazon_product = AmazonProduct.new
  allow(AmazonProduct).to receive(:new).and_return(amazon_product)
  allow(amazon_product).to receive(:respond_to?).with(:visit).and_return(true)
  allow(amazon_product).to receive(:respond_to?).with(:add_to_cart).and_return(true)

  amazon_cart = AmazonCart.new
  allow(AmazonCart).to receive(:new).and_return(amazon_cart)
  allow(amazon_cart).to receive(:respond_to?).with(:visit).and_return(true)
  allow(amazon_cart).to receive(:respond_to?).with(:checkout).and_return(true)

  return amazon_search, amazon_product, amazon_cart
end

RSpec.describe TestWorkflow do
  before(:each) do
    @example = ExampleWorkflow.new
    allow(DataBuilder).to receive(:load)
  end

  it "has a version number" do
    expect(TestWorkflow::VERSION).not_to be nil
  end

  #it "stores the paths" do
  #  paths = %w(path1 path2 path3)
  #  ExampleWorkflow.paths = { :default => paths }
  #  expect(ExampleWorkflow.paths[:default]).to be paths
  #end

  #it "stores data associated with the path" do
  #  ExampleWorkflow.path_data = {:default => :testing}
  #  expect(ExampleWorkflow.path_data).to eq({:default => :testing})
  #end

  it "can perform all paths for a given workflow" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    expect(amazon_search).to receive(:search_for)
    expect(amazon_product).to receive(:add_to_cart)
    expect(amazon_cart).to receive(:checkout)

    @example.entire_path
  end

  it "can start in the middle of a workflow and proceed from there" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    expect(amazon_search).not_to receive(:search_for)
    expect(amazon_product).to receive(:add_to_cart)
    expect(amazon_cart).not_to receive(:checkout)

    @example.path_to(AmazonCart, :from => AmazonProduct)
  end

  it "can use a specified path of a workflow" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    expect(amazon_search).to receive(:search_for)
    expect(amazon_product).to receive(:add_to_cart)
    expect(amazon_cart).not_to receive(:checkout)

    @example.path_to(AmazonCart, :using => :trekking)
  end

  it "passes parameters to methods during path execution" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    expect(amazon_product).to receive(:add_to_cart).with('Vector Prime')

    @example.path_to(AmazonCart, :from => AmazonProduct)
  end

  it "establishes the context via visit call when specified" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    expect(amazon_search).to receive(:visit)
    expect(amazon_search).to receive(:search_for)
    expect(amazon_product).to receive(:add_to_cart)
    expect(amazon_product).not_to receive(:visit)

    @example.path_to(AmazonCart, visit: true)
  end

  it "does not establish the context if specifically told not to visit" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    expect(amazon_search).not_to receive(:visit)
    expect(amazon_search).to receive(:search_for)
    expect(amazon_product).to receive(:add_to_cart)

    @example.path_to(AmazonCart, visit: false)
  end

  it "does not establish the context by default" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    expect(amazon_search).not_to receive(:visit)
    expect(amazon_search).to receive(:search_for)
    expect(amazon_product).to receive(:add_to_cart)

    @example.path_to(AmazonCart)
  end

  it "can continue a path from a provided context" do
    amazon_search, amazon_product, amazon_cart = mock_workflow_usage

    @example.current_context = amazon_product

    expect(amazon_search).not_to receive(:search_for)
    expect(amazon_product).to receive(:add_to_cart)

    @example.continue_path_to(AmazonCart)
  end

  it "fails when a path is not found" do
    expect { @example.path_to(AmazonWishList) }.to raise_error NameError
  end

  it "fails when an action is not found on a path" do
    expect { @example.path_to(AmazonProduct).place_in_cart }.to raise_error RuntimeError
  end

  it "fails when no default path is specified" do
    expect { ExampleWorkflow.paths = {:test_path => []} }.to raise_error RuntimeError
  end
end
