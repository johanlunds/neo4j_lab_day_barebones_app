http://rdoc.info/github/andreasronge/neo4j-core/Neo4j.query
https://github.com/andreasronge/neo4j/wiki/Neo4j%3A%3ACore-Cypher

    Neo4j._query("START n=node(1) RETURN n").first[:n].props

# class Company
#   include Neo4j::NodeMixin
#   has_n(:employees)
# end

# class Person
#   include Neo4j::NodeMixin
#   property :name
#   property :age, :size, :type => Fixnum, :index => :exact
#   property :description, :index => :fulltext

#   has_one(:best_friend)
#   has_n(:employed_by).from(:employees)
# end


# get '/hi' do
#   Neo4j::Transaction.run do
#     Person.new(:name => 'jimmy', :age => 35)
#   end

#   person = Person.find(:age => (10..42)).first

#   Neo4j::Transaction.run do
#     person.best_friend = Person.new
#     person.employed_by << Company.new(:name => "Foo ab")
#   end

#   # find by navigate incoming relationship
#   company = person.employed_by.find { |p| p[:name] == 'Foo ab' }
#   puts "Person #{person.name} employed by #{company[:name]}"
#   # navigate the outgoing relationship:
#   company.employees.each {|x| puts x.name}

#   "Hello: " + company.employees.map {|x| x.name}.join(", ")
# end