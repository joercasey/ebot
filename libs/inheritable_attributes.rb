# This source file, originating from Ruby on Rails, extends the +Class+ class to
# allows attributes to be shared within an inheritance hierarchy, but where each
# descendant gets a copy of their parents' attributes, instead of just a pointer
# to the same. This means that the child can add elements to, for example, an
# array without those additions being shared with either their parent, siblings,
# or children, which is unlike the regular class-level attributes that are
# shared across the entire hierarchy.
#
# This functionality is used by Leaf's filter features; if not for this
# extension, then when a subclass changed its filter chain, all of its
# superclasses' filter chains would change as well. This class allows a subclass
# to inherit a _copy_ of the superclass's filter chain, but independently change
# that copy without affecting the superclass's filter chain.
#
# Copyright (c)2004 David Heinemeier Hansson
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# Allows attributes to be shared within an inheritance hierarchy, but where each descendant gets a copy of
# their parents' attributes, instead of just a pointer to the same. This means that the child can add elements
# to, for example, an array without those additions being shared with either their parent, siblings, or
# children, which is unlike the regular class-level attributes that are shared across the entire hierarchy.
class Class # :nodoc:
  def class_inheritable_reader(*syms)
    syms.each do |sym|
      next if sym.is_a?(Hash)
      class_eval <<-EOS
        def self.#{sym}
          read_inheritable_attribute(:#{sym})
        end

        def #{sym}
          self.class.#{sym}
        end
      EOS
    end
  end

  def class_inheritable_writer(*syms)
    options = syms.last.is_a?(Hash) ? syms.pop : {}
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)
          write_inheritable_attribute(:#{sym}, obj)
        end

        #{"
        def #{sym}=(obj)
          self.class.#{sym} = obj
        end
        " if options[:instance_writer] }
      EOS
    end
  end

  def class_inheritable_array_writer(*syms)
    options = syms.last.is_a?(Hash) ? syms.pop : {}
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)
          write_inheritable_array(:#{sym}, obj)
        end

        #{"
        def #{sym}=(obj)
          self.class.#{sym} = obj
        end
        " if options[:instance_writer] }
      EOS
    end
  end

  def class_inheritable_hash_writer(*syms)
    options = syms.last.is_a?(Hash) ? syms.pop : {}
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)
          write_inheritable_hash(:#{sym}, obj)
        end

        #{"
        def #{sym}=(obj)
          self.class.#{sym} = obj
        end
        " if options[:instance_writer] }
      EOS
    end
  end

  def class_inheritable_accessor(*syms)
    class_inheritable_reader(*syms)
    class_inheritable_writer(*syms)
  end

  def class_inheritable_array(*syms)
    class_inheritable_reader(*syms)
    class_inheritable_array_writer(*syms)
  end

  def class_inheritable_hash(*syms)
    class_inheritable_reader(*syms)
    class_inheritable_hash_writer(*syms)
  end

  def inheritable_attributes
    @inheritable_attributes ||= EMPTY_INHERITABLE_ATTRIBUTES
  end

  def write_inheritable_attribute(key, value)
    if inheritable_attributes.equal?(EMPTY_INHERITABLE_ATTRIBUTES)
      @inheritable_attributes = {}
    end
    inheritable_attributes[key] = value
  end

  def write_inheritable_array(key, elements)
    write_inheritable_attribute(key, []) if read_inheritable_attribute(key).nil?
    write_inheritable_attribute(key, read_inheritable_attribute(key) + elements)
  end

  def write_inheritable_hash(key, hash)
    write_inheritable_attribute(key, {}) if read_inheritable_attribute(key).nil?
    write_inheritable_attribute(key, read_inheritable_attribute(key).merge(hash))
  end

  def read_inheritable_attribute(key)
    inheritable_attributes[key]
  end

  def reset_inheritable_attributes
    @inheritable_attributes = EMPTY_INHERITABLE_ATTRIBUTES
  end

  private
  # Prevent this constant from being created multiple times
  EMPTY_INHERITABLE_ATTRIBUTES = {}.freeze unless const_defined?(:EMPTY_INHERITABLE_ATTRIBUTES)

  def inherited_with_inheritable_attributes(child)
    inherited_without_inheritable_attributes(child) if respond_to?(:inherited_without_inheritable_attributes)

    if inheritable_attributes.equal?(EMPTY_INHERITABLE_ATTRIBUTES)
      new_inheritable_attributes = EMPTY_INHERITABLE_ATTRIBUTES
    else
      new_inheritable_attributes = inheritable_attributes.inject({}) do |memo, (key, value)|
        memo.update(key => (value.dup rescue value))
      end
    end

    child.instance_variable_set('@inheritable_attributes', new_inheritable_attributes)
  end

  alias inherited_without_inheritable_attributes inherited
  alias inherited inherited_with_inheritable_attributes
end
