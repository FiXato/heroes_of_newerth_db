require 'rubygems'
# require 'nokogiri'
require 'hpricot'
require 'open-uri'
require 'string_patches'

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
    @image_url ||= @body.search("/p//img").first.attributes['src']
  end

  def title
    @title ||= @body.search("/h1").inner_html
  end

  def price
    @price ||= (@body/"//p").map{|para| price = para.inner_html.strip.gsub!(/Price:?\s*/,'')}.compact.first
  end

  def value
    @value ||= (@body/"//p").map{|para| price = para.inner_html.strip.gsub!(/Value:?\s*/,'')}.compact.first
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
      if death_notes_header = @body.search("//p//*[text()*='On Death']").first
        active_para = death_notes_header
        while active_para.pathname != 'p' do
          active_para = active_para.parent
        end
        while (active_para = active_para.next_sibling) && active_para.containers.reject{|e|e.empty?} == [] do
          active_para.inner_html.split('.').each do |note|
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
      if requires_header = @body.search("//p//*[text()*='Requires']").first
        active_para = requires_header
        while active_para.pathname != 'p' do
          active_para = active_para.parent
        end
        while (active_para = active_para.next_sibling) && (active_para.search("a").size > 0 || (active_para.pathname == 'p' && active_para.inner_html.last_word.to_i > 0)) do
          @requires << active_para.inner_html
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
      elements << body.inner_html
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
    @body.search("script").remove
    @body.search("#hmt-widget-additional-unit-1").remove
    @body.search("#hmt-widget-link-unit-2").remove
    @body.search("/h1").remove
    @body.search("img").remove
    # @body.search("br").remove
    @body.search("//comment()").remove
    @body.traverse_element do |e|
      if e.respond_to? :attributes
        e.remove_attribute('style')
        e.remove_attribute('class')
        e.remove_attribute('id')
      end
      e.parent.search('a').remove if e.pathname == 'a' && e.empty?
      e.parent.search('strong').remove if e.pathname == 'strong' && e.empty?
      e.swap(e.inner_html) if %w[strong].include?(e.pathname) && !e.empty?
    end
    nil
  end

  def retrieve_bonuses(needle)
    bonuses = []
    if active_paragraph = @body.search("//p//*[text()*='#{needle}']").first
      while active_paragraph.pathname != 'p' do
        active_paragraph = active_paragraph.parent
      end
      # Fix newlined paragraphs
      if active_paragraph.search("br").size > 0
        elements = []
        active_paragraph.traverse_element do |e|
          if e.pathname == 'br'
            elements << "<p>#{e.next.to_s.strip}</p>" if e.next
          end
        end
        elements << '<p><span class="dummy">&nbsp;</span></p>'
        active_paragraph.after elements.join("\n")
      end
      while (active_paragraph = active_paragraph.next_sibling) && active_paragraph.containers.reject{|e|e.empty?} == [] do
        bonuses << active_paragraph.inner_html
      end
    end
    bonuses
  end
end

def get_doc(url)
  open(url, "User-Agent" => "Ruby/#{RUBY_VERSION}", "Referer" => "#{url}") { |f| Hpricot(f) }
  # Nokogiri::HTML(open(url, "User-Agent" => "Ruby/#{RUBY_VERSION}", "Referer" => "#{url}"))
end