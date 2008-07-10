# FakeMechanics
require 'digest/md5'
  
class Wiretapper
  attr_reader :wiretapper
  
  def initialize(options={})
    @target_klass = options[:target_klass] ||= Net::HTTP
    @target_method = options[:target_method] ||= :request
    @data_store = options[:data_store]    
    @wiretapper = options[:wiretapper] ||= method(:wiretapper)
  end
  
  def snoop(*args, &block)
    start_wiretap
    yield
  ensure
    end_wiretap
  end
  
  def capture(obj_for_key)
    key = create_key(obj_for_key)
    value = yield
    @data_store.store(key, Marshal.dump(value))
    value
  end
  
  def create_key(name)
    Digest::MD5.hexdigest(name.to_s)
  end
  
  def captured_transmission(obj_for_key)
    key = create_key(obj_for_key)
    value = @data_store.get(key)
    Marshal.restore(value) if value
  end
  
  def wiretapper(*args, &block)
    raise "Wiretapper must be implemented in a subclass"
  end
  
  def start_wiretap
    @original_method ||= @target_klass.instance_method(@target_method)
    
    @target_klass.send :define_method, "__#{@target_method}_old", @original_method
    @target_klass.send :class_variable_set, "@@wiretapper", @wiretapper
    @target_klass.class_eval <<-DEF
      def #{@target_method}(*args, &block)
        # revert the target method override, so only the outer most method call is captured, avoiding multiple captures on recursion
        self.class.send :remove_method, :#{@target_method}
        self.class.send :define_method, :#{@target_method}, method('__#{@target_method}_old')
        args << method('__request_old')
        @@wiretapper.call(*args, &block)
      end
    DEF
  end
  
  def end_wiretap
    @target_klass.send :remove_method, @target_method
    @target_klass.send :remove_method, "__#{@target_method}_old"
    @target_klass.send :define_method, @target_method, @original_method
    @target_klass.send :class_variable_set, "@@wiretapper", nil
  end
end

class NetHTTPWiretapper < Wiretapper
  def initialize(options={})
    options.merge! :target_klass => Net::HTTP, :target_method => :request
    super(options)
  end
  
  def wiretapper(*args, &block)
    req = args.shift
    meth = args.pop
    body = args.shift
    
    if transmission = captured_transmission(req)
      yield transmission if block_given?
      return transmission
    else
      capture(req) do
        meth.call(req, body, &block)
      end
    end
  end
end

class SQLiteDatastore
  def initialize(name)
    require 'sqlite3'
    # TODO: Check if db name is in a directory, and create it if it doesn't already exist
    @db = SQLite3::Database.new( "#{name}.db" )
    @db.execute "create table wiretaps(wiretap_key varchar(255) primary key, interception blob);" unless tables.include? "wiretaps"
  end
  
  def store(key, value)
    if get(key)
      @db.execute "update wiretaps set interception = ? where wiretap_key = ?", value, key
    else
      @db.execute "insert into wiretaps values(?, ?)", key, value
    end
  end
  
  def get(key)
    @db.get_first_row("select interception from wiretaps where wiretap_key = ?", key)[0]
  end
  
  private
  def tables(name = nil) #:nodoc:
    sql = <<-SQL
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND NOT name = 'sqlite_sequence'
    SQL

    @db.execute(sql, name).map do |row|
      row[0]
    end
  end
end
# 
# Wiretap.set_data_store :type => :sqlite, :connection => connection
# Wiretap.set_data_store :s3
# Wiretap.set_data_store :yml, :location => 'file'