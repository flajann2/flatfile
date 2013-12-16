=begin rdoc
AtlasMapper == Map Atlas 
=end
require 'pp'

module AtlasMapper
  class AMap
    attr_accessor :fields, :looping, :parent

    # looping: :stag to loop over.
    # parent: parent AMap in nested constructs.
    def initialize(attr = {})
      @parent = attr[:parent]
      @fields = []
      @looping = attr[:looping]
      @conditions = []
    end

    # DSL - handle a new field
    def field(atlasfield, length, sourcetag, default = nil, &block)
      @fields << {
        afield: atlasfield, 
        length: length, 
        stag: sourcetag,
        default: default,
        block: block
      }
    end
    
    # DSL - looping: :stag to loop over.
    def line(name = nil, attr = {}, &block)
      linemap = AMap.new parent: self, looping: attr[:looping]
      @fields << linemap
      linemap.fields << [:begin, name]
      block.call(linemap)
      linemap.fields << [:end, name]
    end

    # DSL - For looping only -- conditional as to whether or not this
    #       line should be created.
    def condition(stag, &block)
      @conditions << [stag, block]
    end

    # NOT PART OF THE DSL -- for looing constructs,
    # tell us if we should reject this amap with regard to the given
    # looping object.
    def reject?(lob)
      # @conditions has a list of [stag, block]
      # if stag is :lob, then use the looping object (which should normally be the case)
      #
      # Check all conditions and they all must be true for the reject to return false.
      # If any condition returns false, reject? must return true. Basically, this is a NAND
      # operation.
      ! (@conditions.empty? or 
          @conditions.map {|stag, block|
            raise Exception("#{stag} NIY: can only handle :lob now.") unless stag == :lob
            block.call(lob)
          }.reduce {|all, current| all && current})
    end
  end

  module ClassMethods
    def atlas(&block)
      @@amap = AMap.new
      block.call(@@amap)
    end

    # Render the results
    def render
      @@amap.render
    end

    def amap
      @@amap
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  def register(h)
    @objects = {} if @objects.nil?
    h.each { |tag, ob|
      @objects[tag] = ob
    }
  end
  alias :<< :register

  # return the string representation of the field
  # loopob is a singular hash that contails the stag
  # of the ob in question along with the ob in question!
  def render_field(field, loopob = {})
    # :afield, :length, :stag, :block
    # we have to find the corresponding object
    f = nil
    ob = if loopob.member? field[:stag]
           loopob[field[:stag]]
         else
           @objects[field[:stag]]
         end
    f = field[:block].call(ob) unless ob.nil? || field[:block].nil?
    f = field[:default] if f.nil? or f.to_s.size == 0
    f = f.to_s[0...field[:length]]
    f.ljust field[:length]
  end

  # render what we have.
  def render(attr = {})
    amap = unless attr[:amap].nil?
             attr[:amap]
           else
             self.class.amap
           end
        
    def _inner_spire(amap, lob = nil)
      amap.fields.map do |field|
        # here field will either be a hash or an array.
        # if an array, it is a marker for the beginning and ending of a line.
        if field.kind_of? Array
          case field.first
          when :begin
            ''
          when :end
            "\n"
          else
            raise Exception.new "Unknown delimiter type #{field}"
          end
        elsif field.kind_of? Hash
          render_field field, amap.looping => lob
        elsif field.kind_of? AMap
          render amap: field
        else
          raise Exception.new("Unknown Field Type #{field.class}")
        end
      end.join
    end
    
    unless amap.looping.nil?
      unless @objects[amap.looping].nil?
        @objects[amap.looping].map { |lob|
          _inner_spire(amap, lob) unless amap.reject? lob
        }.join
      else
        ''
      end
    else
      _inner_spire amap
    end
  end
end
