require 'htmlentities'
@@coder = HTMLEntities.new
class String
  def snake_case
    @@coder.decode(self).downcase.gsub(/\W/,'_').gsub("’",'').gsub(/_+/,'_')
  end

  def last_word
    self.split(' ').last
  end
end
