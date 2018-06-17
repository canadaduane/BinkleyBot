require 'google/apis/sheets_v4'

module GSheets
  class Client
    def initialize
      if !ENV["GOOGLE_APPLICATION_CREDENTIALS"] && File.file?(credentials_filepath)
        ENV["GOOGLE_APPLICATION_CREDENTIALS"] = credentials_filepath
      else
        $stderr.puts "WARNING -- Missing Google API Credentials: #{Dir.pwd}/GoogleAPICredentials.json"
      end
    end

    def credentials_filepath
      File.join(Dir.pwd, "GoogleAPICredentials.json")
    end

    def service
      @service ||= create_sheets_service
    end

    def create_sheets_service
      if ENV["GOOGLE_APPLICATION_CREDENTIALS"]
        scopes = ['https://www.googleapis.com/auth/drive']
        authorization = Google::Auth.get_application_default(scopes)
    
        Google::Apis::SheetsV4::SheetsService.new.tap do |s|
          s.authorization = authorization
        end
      else
        $stderr.puts "ERROR -- Can't create SheetsService without Google Credentials"
        exit(-1)
      end
    end

    def sheet(docid, sheet_name)
      Sheet.new(service, docid, sheet_name)
    end
  end

  class Sheet
    def initialize(service, docid, sheet_name)
      @service, @docid, @sheet_name = [service, docid, sheet_name]
    end

    def range_to_a1(range)
      if range.nil?
        @sheet_name
      elsif range.include?("!")
        range
      else
         "#{@sheet_name}!#{range}"
      end
    end

    def values(range = nil)
      @service.get_spreadsheet_values(@docid, range_to_a1(range), value_render_option: "UNFORMATTED_VALUE")
    end

    def value(range = nil)
      values(range).values.first.first
    end

    def append_row(values)
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: [values])
      @service.append_spreadsheet_value(@docid, @sheet_name, value_range, value_input_option: "USER_ENTERED")
    end

    def clear(range)
      request_body = Google::Apis::SheetsV4::ClearValuesRequest.new
      @service.clear_values(@docid, range_to_a1(range), request_body)
    end
  end
end

__END__

# Sample code:
c = GSheets::Client.new
s = c.sheet("1r9dSbMUS1svw5UkA9Nhw3ZcGNKoMIdTS0noi1P7dZW8", "Transactions")
r = s.append_row([Time.now, "Duane", "50.0", "2.99", "Test insert 6"])
s.clear(r.updates.updated_range)

# get single value
s.value("B2")
