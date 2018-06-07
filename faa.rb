require 'nokogiri'
require 'rest-client'

module FAA
  class DataFetcher
    OIS_TABLES = { national_program: 0, ground_stop: 2, delay_info: 5, closure: 7, deicing: 10 }
    OIS_URL = 'https://www.fly.faa.gov/ois/jsp/summary_sys.jsp'

    def self.delays
      delays = []

      page = RestClient.get(OIS_URL).body
      tables = Nokogiri::HTML(page).css('table')

      OIS_TABLES.each do |delay_type, index|
        table = tables[index]
        headings = table.css('tr')[2].children.map(&:content).select { |c| !c.include?("\n") }.map(&:downcase)
        rows = table.css('tr')

        rows[3..(rows.length - 1)].each do |row|
          items = row.css('td').map(&:content).map { |c| c.strip }
          opts = Hash[headings.zip(items)]
          opts.delete('da')

          delays << Delay.new(
            {
              type: delay_type,
              affecting: [opts.delete("program name") || opts.delete('arpt')] || [],
              reason: opts.delete('reason') || '',
              advisory: (opts.delete('advzy') || "").strip,
              time: opts.delete('time') || opts.delete('date/time') || ''
            }.merge(opts)
          )
        end
      end

      delays
    end
  end

  class Delay
    def initialize(options = {})
      @options = options
    end

    def method_missing(method, *args, &block)
      if @options.key?(method)
        @options[method]
      else
        super(method, *args, &block)
      end
    end
  end

  class OIS
    class << self
      def delays_affecting(airport)
        DataFetcher.delays.select do |delay|
          delay.affecting.include?(airport)
        end
      end
    end
  end
end

puts FAA::OIS.delays_affecting(ENV['AIRPORT'])
