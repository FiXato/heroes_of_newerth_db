require 'rubygems'
require 'nokogiri'
require 'string_patches'

class Nokogiri::XML::Element
  def flattened_elements
    elements = []
    self.traverse do |e|
      elements << e if e.element?
    end
    elements
  end
end

class Item
  attr_accessor :title, 
    :price, 
    :value, 
    :passive_bonuses, 
    :active_bonuses, 
    :death_notes, 
    :requires, 
    :cyclone_effects, 
    :url, 
    :image_url,
    :body
  attr_reader :errors
  
  def initialize(url)
    @errors = []
    @url = url
    @doc = get_doc(url)
    @body = (@doc/"/html/body/div[3]/div[9]/div/div")
    cache_details
  rescue Exception => e
    @errors << e
  end

  def cache_details
    title
    image_url
    cleanup_body
    price
    value
    passive_bonuses
    active_bonuses
    requires
    cyclone_effects
    nil
  end

  def image_url
    @image_url ||= @body.xpath("p//img").first.attributes['src']
  end

  def title
    @title ||= @body.xpath("h1").inner_html
  end

  def price
    @price ||= @body.xpath("p").map{|para| price = para.inner_html.strip.gsub!(/Price:?\s*/,'')}.compact.first
  end

  def value
    @value ||= @body.xpath("p").map{|para| price = para.inner_html.strip.gsub!(/Value:?\s*/,'')}.compact.first
  end

  def passive_bonuses
    unless @passive_bonuses
      @passive_bonuses = retrieve_bonuses('Passive Bonus')
    end
    @passive_bonuses
  end

  def active_bonuses
    unless @active_bonuses
      @active_bonuses = retrieve_bonuses('Activation')
    end
    @active_bonuses
  end

  def cyclone_effects
    unless @cyclone_effects
      @cyclone_effects = retrieve_bonuses('Cyclone Effects')
    end
    @cyclone_effects
  end

  def death_notes
    unless @death_notes
      @death_notes = []
      if death_notes_header = @body.xpath("p//text()").select{|e|e.text.include?('On Death')}.first
        active_paragraph = death_notes_header
        while active_paragraph.name != 'p' do
          active_paragraph = active_paragraph.parent
        end
        while (active_paragraph = active_paragraph.next_sibling) do
          next if (active_paragraph.name == 'p' || active_paragraph.name == 'text') && active_paragraph.blank?
        # while (active_para = active_para.next_sibling) && active_para.containers.reject{|e|e.empty?} == [] do
          break if active_paragraph.flattened_elements.reject{|e|e.blank? || e.content.strip == ''}.size > 1
          active_paragraph.inner_html.split('.').each do |note|
            @death_notes << '%s.' % note.strip
          end
        end
      end
    end
    @death_notes
  end

  def requires
    unless @requires
      @requires = []
      if requires_header = @body.xpath("p//text()").select{|e|e.text.include?('Requires')}.first
        active_paragraph = requires_header
        while active_paragraph.name != 'p' do
          active_paragraph = active_paragraph.parent
        end
        fix_newlined_paragraph(active_paragraph)
        while active_paragraph = active_paragraph.next_sibling do
          next if active_paragraph.text == "\n"
          break unless (active_paragraph.xpath("a").size > 0 || (active_paragraph.name == 'p' && active_paragraph.inner_html.last_word.to_i > 0))
          @requires << active_paragraph.inner_html
        end
      end
    end
    @requires
  end

  def to_html_div
    elements = []
    if errors.size == 0
      elements << '<div id="%s" class="item">' % title.snake_case
      elements << '  <h2 class="title"><a href="%s">%s</a></h2>' % [url,title]
      elements << '  <a href="%s"><img class="icon" alt="%s Icon" src="%s" /></a>' % [url,title.gsub('"',"'"),image_url]
      elements << '  <label class="price">Price:</label><span class="price">%s</span>' % price if price
      elements << '  <label class="value">Value:</label><span class="value">%s</span>' % value if value
      if passive_bonuses.size > 0
        elements << '  <h3 class="passive-bonuses">Passive Bonuses:</h3>'
        elements << '  <ul class="passive-bonuses">'
        passive_bonuses.each do |bonus|
          elements << '  <li class="passive-bonus">%s</li>' % bonus
        end
        elements << '  </ul>'
      end
      if active_bonuses.size > 0
        elements << '  <h3 class="active-bonuses">When Activated:</h3>'
        elements << '  <ul class="active-bonuses">'
        active_bonuses.each do |bonus|
          elements << '    <li class="active-bonus">%s</li>' % bonus
        end
        elements << '  </ul>'
      end
      if cyclone_effects.size > 0
        elements << '  <h3 class="cyclone-effects">Cyclone Effects:</h3>'
        elements << '  <ul class="cyclone-effects">'
        cyclone_effects.each do |cyclone_effect|
          elements << '    <li class="cyclone-effect">%s</li>' % cyclone_effect
        end
        elements << '  </ul>'
      end
      if death_notes.size > 0
        elements << '  <h3 class="death-notes">Death Notes:</h3>'
        elements << '  <ul class="death-notes">'
        death_notes.each do |note|
          elements << '  <li class="death-notes">%s</li>' % note
        end
        elements << '  </ul>'
      end
      if requires.size > 0
        elements << '  <h3 class="required-items">Required Items:</h3>'
        elements << '  <ul class="required-items">'
        requires.each do |required_item|
          elements << '  <li class="required-item">%s</li>' % required_item
        end
        elements << '  </ul>'
      end
      elements << '  <span class="raw-toggle" onclick="toggleDisplay(this.parentNode.getElementsByClassName(\'raw\')[0]);">Toggle raw info</span>'
      elements << '  <div class="raw">'
      elements << body.inner_html.strip
      elements << '  </div>'
      elements << '</div>'
    else
      elements << '<div class="errors">'
      elements << '  <span class="url">%s</span>' % url
      elements << '  <ul class="errors">'
      errors.each do |error|
        elements << '  <li class="error">'
        elements << '    <label class="error">%s</label> <span class="error-message">%s</span><p class="error-backtrace">%s</p>' % [error.class.name,error.message, error.backtrace.join("<br />\n")]
        elements << '  </li>'
      end
      elements << '  </ul>'
      elements << '</div>'
    end
    elements.join("\n")
  end

  private
  def cleanup_body
    @body = @body.first
    @body.xpath("//script").remove
    @body.css("#hmt-widget-additional-unit-1").remove
    @body.css("#hmt-widget-link-unit-2").remove
    @body.xpath("//h1").remove
    @body.xpath("//img").remove
    # @body.xpath("//br").remove
    @body.xpath("//comment()").remove
    attributes_to_remove = %w[id class style]
    @body.traverse do |e|
      attributes_to_remove.each{|attr|e.remove_attribute(attr)}
      e.parent.xpath('//a').remove if e.name =='strong' && e.blank?
      e.remove if e.name == 'strong' && e.content.strip == ''
      
      # Fix Nullstone's
      #  <strong>P</strong><strong>assive</strong>
      # broken formatting
      if e.name == 'strong' && e.next_sibling && e.next_sibling.name == 'strong'
        e.content = '%s%s' % [e.content,e.next_sibling.content]
        e.next_sibling.remove
      end
      nil
    end
    nil
  end

  def fix_newlined_paragraph(active_paragraph)
    if active_paragraph.search("br").size > 0
      elements = []
      active_paragraph.traverse do |e|
        if e.name == 'br'
          if e.next
            elements << "<p>#{e.next.to_s.strip}</p>"
            e.next.remove;e.remove
          end
        end
      end
      active_paragraph.after elements.join("") if elements.size > 0
    end
    nil
  end

  def retrieve_bonuses(needle)
    bonuses = []
    if active_paragraph = @body.xpath("p//text()").select{|e|e.text.include?(needle)}.first
      while active_paragraph.name != 'p' do
        active_paragraph = active_paragraph.parent
      end
      fix_newlined_paragraph(active_paragraph)
      while (active_paragraph = active_paragraph.next_sibling) do
        next if (active_paragraph.name == 'p' || active_paragraph.name == 'text') && active_paragraph.blank?
        break if active_paragraph.flattened_elements.reject{|e|e.blank? || e.content.strip == ''}.size > 1
        # break if active_paragraph.containers && active_paragraph.containers.reject{|e|e.empty? or (e.attributes['class'] && e.attributes['class'].include?('dummy'))} != []
        bonuses << active_paragraph.inner_html
      end
    end
    bonuses
  end
end

def cache_url(url)
  `mkdir -p cache` unless File.exist?('cache')
  `wget -q #{url} -O #{cache_filename_for_url(url)}`
end

def cache_filename_for_url(url)
  @cache_filenames ||= {}
  @cache_filenames[url] ||= filename = File.expand_path(File.join('cache',File.basename(url)))
end

def get_doc(url)
  # open(url, "User-Agent" => "Ruby/#{RUBY_VERSION}", "Referer" => "#{url}") { |f| Hpricot(f) }
  # Nokogiri::HTML(open(url, "User-Agent" => "Ruby/#{RUBY_VERSION}", "Referer" => "#{url}"))
  begin
    Nokogiri::HTML(File.read(cache_filename_for_url(url)))
  rescue Errno::ENOENT
    cache_url(url)
    Nokogiri::HTML(File.read(cache_filename_for_url(url)))
  end
end
# 
# def p(*args)
#   puts '<pre>'
#   super(*args)
#   puts '</pre>'
# end