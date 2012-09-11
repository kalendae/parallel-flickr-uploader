require 'rubygems'
require 'yaml'

class Photosets
  
  def initialize(data)
    @data = data
  end
  
  def get_set_by_title(title)
    @data.each{ |s|
      #puts "matching #{s['title']} and #{title}"
      return s if s["title"] == title
    }
    nil
  end
  
  def show
    p @data
  end
end
