# TestWorkflow

[![Gem Version](https://badge.fury.io/rb/test_workflow.svg)](http://badge.fury.io/rb/test_workflow)
[![License](http://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jnyman/test_workflow/blob/master/LICENSE.txt)

TestWorkflow implements the idea of traversing a set of activities in the context of a user workflow.

## Installation

To get the latest stable release, add this line to your application's Gemfile:

```ruby
gem 'test_workflow'
```

And then include it in your bundle:

    $ bundle

You can also install TestWorkflow just as you would any other gem:

    $ gem install test_workflow

## Usage

The core operation of the TestWorkflow is a path. A workflow can have different paths. A path is an array of actions. These actions consist of a class a method on that class. Parameters can also be passed to the methods. The idea here is that the class is acting as context object for test execution. That class may be a page object, a screen object, a service object, and so on.

### Paths

Here's an example of a workflow class with a path:

```ruby
PurchaseFromAmazon.paths = {
  :default => [
    [AmazonSearch, :search_for, "Star Wars"],
    [AmazonProduct, :add_to_cart, "Vector Prime"],
    [AmazonCart, :checkout]
  ]
}
```

Notice how some of the paths are passing arguments to the methods.

Now to run that workflow up to the last point, you could do this:

```ruby
path_to(AmazonCart)
```

This would run the workflow _up to_ the AmazonCart, starting with AmazonSearch and moving on down the list. Note that the first argument is a context definition (i.e., AmazonSearch), the second is a method on that context definition (i.e., :search_for) and the the third item is an optional argument to pass to that method.

Symbiote will always assume there is a default path, and will complain if there is not one. But you can have a different workflow as such:

```ruby
PurchaseFromAmazon.paths = {
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
```

Now you can specify that you want to use that different path:

```ruby
path_to(AmazonCart, using: :trekking)
```

So what you can see here is that you can navigate to a particiular context traversing through all other contexts along the way. The use of the term "context" is deliberate because the workflow could be the traversal of a series of pages. Thus the contexts would be page objects. But the workflow could also be a series of API calls, which means the contexts might be service objects.

### Examples

Consider the following setup:

```ruby
require "test_workflow"

class AmazonSearch
  def search_for(product)
    puts "AmazonSearch - search_for: #{product}"
  end
end

class AmazonProduct
  def add_to_cart(product)
    puts "AmazonProduct - add_to_cart: #{product}"
  end
end

class AmazonCart
  def checkout
    puts "AmazonCart - checkout"
  end
end

class PurchaseFromAmazon
  include TestWorkflow

  def on(caller)
    caller.new
  end
end
```

The `on` method here is critical. This is a part of the API that is exposed by TestWorkflow. What this means is that you should implement this method so that context calls can be made.

You can then do the following:

```ruby
PurchaseFromAmazon.paths = {
  :default => [
          [AmazonSearch, :search_for, "Star Wars"],
          [AmazonProduct, :add_to_cart, "Vector Prime"],
          [AmazonCart, :checkout]
      ]
}

testing = PurchaseFromAmazon.new
testing.path_to(AmazonCart)
```

That would lead to output like this:

    AmazonSearch - search_for: Star Wars
    AmazonProduct - add_to_cart: Vector Prime

You can see the logic is running up to the AmazonCart part of the path. That is by design. You could change that last line to this:

```ruby
testing.path_to(AmazonCart, from: AmazonProduct)
```

That would lead to this output:

    AmazonProduct - add_to_cart: Vector Prime

Here you are saying you want to run the path starting from a particular point in the path.

Let's add a second path to the workflow:
 
```ruby
PurchaseFromAmazon.paths = {
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

testing = PurchaseFromAmazon.new
testing.path_to(AmazonCart, from: AmazonProduct, using: :trekking)
```

The output from this would be:

    AmazonProduct - add_to_cart: Engines of Destiny

Here I'm not only running from a particular point on the path but I'm using a specific path as well.

You can also override the method call. For example, try this:

```ruby
testing.path_to(AmazonProduct).add_to_cart('testing')
```

This would lead to this output:

    AmazonSearch - search_for: Star Wars
    AmazonProduct - add_to_cart: testing

Notice here how the argument passed in is not the default one from the path but the one you specified.

You can also run the entire path by doing this:

```ruby
testing.entire_path
```

You'll note here that I've defined the paths outside of the workflow class, but you can easily do otherwise, as such:

You can also continue executing a path that you previously started. Consider this logic:

```ruby
testing = PurchaseFromAmazon.new

testing.path_to(AmazonProduct)
testing.current_context = AmazonProduct.new

# Do some other logic here.
puts "Other Logic Happens Here."

testing.continue_path_to(AmazonCart)
```

The output would be:

    AmazonSearch - search_for: Star Wars
    Other Logic Happens Here.
    AmazonProduct - add_to_cart: Vector Prime

What this is showing you is that a path can be started, then other work can be done, and then the path can be re-entered at a particular starting point. Key to this is the use of `current_context` which you would want to define on any of your classes that include TestWorkflow. For example, with the above logic you would have:

```ruby
class PurchaseFromAmazon
  include TestWorkflow

  attr_accessor :current_context
  # ...
end
```

You have to maintain the `@current_context` instance variable which should always point to the current object in the workflow path. This gives you a minimal way to control the execution of paths by executing them up to a point, interleaving other activities you might want to perform, and then continuing on from where you left off.

### Code Considerations

From a code perspecive, `path_to` is a key method. It takes in a context as well as a path. That path will be a hash that contains two elements. One of the elements is the key :using. This is what is used to lookup the path to traverse. You can see that in the example above. This key will have a default value of :default. The second key that can be specified is :visit. This specifies whether the execution context should be specifically set up, as opposed to assuming that the context already exists. The default value of :visit is false.

Another method to be aware of is `entire_path`, which was covered above. This is used to traverse through a complete workflow based on the paths, executing any methods specified.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec:all` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/jnyman/test_workflow](https://github.com/jnyman/test_workflow). The testing ecosystem of Ruby is very large and this project is intended to be a welcoming arena for collaboration on yet another testing tool. As such, contributors are very much welcome but are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

To contribute to TestWorkflow:

1. [Fork the project](http://gun.io/blog/how-to-github-fork-branch-and-pull-request/).
2. Create your feature branch. (`git checkout -b my-new-feature`)
3. Commit your changes. (`git commit -am 'new feature'`)
4. Push the branch. (`git push origin my-new-feature`)
5. Create a new [pull request](https://help.github.com/articles/using-pull-requests).

## Author

* [Jeff Nyman](http://testerstories.com)

## Credits

This code is loosely based upon the [PageNavigation](https://github.com/cheezy/page_navigation) gem. The rationale for a new version is that tying the project to "page navigation" in particular is limiting, particularly since workflow-based patterns (like journey and screenplay) are often much more effective from a testing standpoint.

## License

TestWorkflow is distributed under the [MIT](http://www.opensource.org/licenses/MIT) license.
See the [LICENSE](https://github.com/jnyman/test_workflow/blob/master/LICENSE.txt) file for details.

