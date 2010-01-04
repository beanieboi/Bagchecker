#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'open-uri'
require 'rexml/document'
require 'trollop'

class Bagchecker
  def initialize(options)
    @options = options
  end

  def check_bags
    responses = read_xml.map do |bag|
      read_html(bag)
    end

    output = responses.find_all { |item| !item.nil? }
    output.sort.each { |out| puts out}
  end

  private
  def read_html(bag)
    outlet_id = bag.fetch "outlet_id" 
    bag_id = bag.fetch "bag_id"
    
    doc = Nokogiri::HTML(open("http://tracking.orwonet.de/rossmann/orderdetails.jsp?bagId=#{bag_id}&outletId=#{outlet_id}"))
    
    date_or_not_exists = doc.xpath('//*[contains(concat( " ", @class, " " ), concat( " ", "boxFull", " " ))]').text
    if date_or_not_exists.include? "Auftrag nicht gefunden"
      return "Tasche #{bag_id} existiert nicht"
    end
    
    status = doc.xpath('//tr[(((count(preceding-sibling::*) + 1) = 5) and parent::*)]//*[(((count(preceding-sibling::*) + 1) = 2) and parent::*)]').first.text

    if status == "Versendet"
        "Tasche #{bag_id} wurde am #{date_or_not_exists.split(" ").at(9)} ausgeliefert"
    else
        "Tasche: #{bag_id} Nicht versendet"
    end
  end

  def read_xml
    begin
        bag_file = File.read(@options[:input])
        bag_document = REXML::Document.new(bag_file)
        bags = parse_xml(bag_document)
    rescue NoMethodError
        puts "File #{@options[:input]} could not be parsed!"
    rescue
        puts "File #{@options[:input]} not found!"
    end
    return bags if bags
  end
  
  def parse_xml(document)
      bags = Array.new
      
      REXML::XPath.each(document, "//bag") do |bag|
        bag_hash = Hash.new
        bag_hash.store("outlet_id", bag.elements["outlet_id"].text)
        bag_hash.store("bag_id", bag.elements["bag_id"].text)
        bags << bag_hash
      end
    bags
  end
end

options = Trollop::options do
   version "bagchecker.rb 0.1 (c) 2010 beanie"
   banner <<-EOS
This is a small script, which checks your analog photo bag against the webservice of Rossmann

Usage:
bagchecker.rb -i <filename>

EOS
   opt :input, "Input bag file", :type => String
end

if (options[:input].nil? or !File.exist?(options[:input]))
   Trollop::die "must specify an existent input file"
end

checker = Bagchecker.new(options)
checker.check_bags