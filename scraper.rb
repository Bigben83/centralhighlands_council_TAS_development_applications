require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'

# Initialize the logger
logger = Logger.new(STDOUT)

# Define the URL of the page
url = 'https://centralhighlands.tas.gov.au/development-applications/'

# Step 1: Fetch the page content
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create table
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS centralhighlands (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT,
    title_reference TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
title_reference = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = Date.today.to_s

# Extract data from the page content
doc.css('div.twelve.columns').each do |row|
  # Extract the address (location part before the parentheses)
  address = row.at_css('p:contains("Location:")').text.split('Location:').last.split('(').first.strip

  # Extract the proposal (contains both the council reference and description)
  proposal_text = row.at_css('p:contains("Proposal:")').text.split('Proposal:').last.strip
  council_reference = proposal_text.split('–').first.strip
  description = proposal_text.split('–').last.strip

  # Extract the on notice date (date in <strong> tag after 'until')
  on_notice_to = row.at_css('p:contains("until") strong').text.strip
  on_notice_to = Date.strptime(on_notice_to, "%d %B %Y").to_s

  # Log the extracted data
  logger.info("Extracted Data: Address: #{address}, Council Reference: #{council_reference}, Description: #{description}, On Notice To: #{on_notice_to}")
  
  # Insert into the database or check for duplicates, etc.
  existing_entry = db.execute("SELECT * FROM centralhighlands WHERE council_reference = ?", council_reference)
  if existing_entry.empty?
    # Save data to the database
    db.execute("INSERT INTO centralhighlands (address, council_reference, description, on_notice_to) 
      VALUES (?, ?, ?, ?)", [address, council_reference, description, on_notice_to])

    logger.info("Data for #{council_reference} saved to database.")
  else
    logger.info("Duplicate entry for document #{council_reference} found. Skipping insertion.")
  end
end
