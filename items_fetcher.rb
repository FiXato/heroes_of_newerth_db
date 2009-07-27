require 'item'

class ItemsFetcher
  attr_accessor :doc, :items  
  
  def initialize
    @doc = get_doc("http://heroes-newerth.com/items")
    @items = []
  end

  def get_item(url)
    @items << Item.new(url)
  end

  def get_first_item
    i = (doc/"/html/body/div[3]/div[9]/div/div/address//a").first
    get_item(i.attributes['href'])
  end

  def get_items
    (doc/"/html/body/div[3]/div[9]/div/div/address").each do |item_group|
      item_group.search("/a").each do |i|
        get_item(i.attributes['href'])
      end
    end
  end

  def to_html
    body = items.map{|i| i.to_html_div}.join("\n")
    html =<<-HTMLTEXT
    <!DOCTYPE html>
    <html lang='en-gb' xmlns='http://www.w3.org/1999/xhtml'>
    <head>
      <meta charset="utf-8" />
      <title>Heroes of Newerth Items</title>
      <link rel="stylesheet" type="text/css" href="screen.css" />
      <script type="text/javascript" href="hon.js"></script>
    </head>
    <body>
      <h1 id="hon_items">Heroes of Newerth Items</h1>
      #{body}
    </body>
    </html>
    HTMLTEXT
  end
end