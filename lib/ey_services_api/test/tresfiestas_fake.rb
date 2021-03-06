class TresfiestasFake
  BASE_URL = "http://mockservice.test"

  def self.setup!
    @mock_helper = MockHelper.new
  end
  def self.reset!
    @services = {}
    @invoices = []
    @status_messages = []
  end
  def self.services
    @services ||= {}
  end
  def self.invoices
    @invoices ||= []
  end
  def self.status_messages
    @status_messages ||= []
  end

  def self.mock_helper
    MockHelper.new
  end

  class MockHelper
    def reset!
    end
    def initialize_api_connection
      EY::ServicesAPI.setup!(:auth_id => "123", :auth_key => "456")
      EY::ServicesAPI.connection.backend = TresfiestasFake::RackApp
    end

    def partner
      {
        :registration_url => "#{BASE_URL}/api/1/register_a_new_service",
        :auth_id => "123",
        :auth_key => "456",
      }
    end

    def service_registration_params
      {
        :name => "Mocking Bird",
        :description => "a mock service",
        :service_accounts_url =>     "#{BASE_URL}/api/1/customers/regular",
        :home_url =>                 "#{BASE_URL}/",
        :terms_and_conditions_url => "#{BASE_URL}/terms",
        :vars => [
          "MOCK_API_KEY"
        ]
      }
    end

    def service_account
      {:invoices_url => "#{BASE_URL}/api/1/invoices/12",
       :messages_url => "#{BASE_URL}/api/1/messages/12",
       :id => 12}
    end

    def service_account_creation_request(service_account_hash)
      {}
    end

    def provisioned_service_creation_request(service_account_hash)
      {:environment => {}, :app => {}}
    end

    def latest_invoice
      invoice = TresfiestasFake.invoices.last
      {
        :total_amount_cents  => invoice['total_amount_cents'],
        :line_item_description => invoice['line_item_description'],
        :service_account_id => invoice['service_account_id'],
      }
    end

    def latest_status_message
      message = TresfiestasFake.status_messages.last
      to_return = {
        :subject => message["subject"],
        :body => message["body"],
      }
      if message['provisioned_service_id']
        to_return.merge!(:provisioned_service_id => message['provisioned_service_id'])
      end
      to_return
    end

    def provisioned_service
      {:messages_url => "#{BASE_URL}/api/1/provisioned_service_messages/64",
      :id => 64}
    end
  end

  class RackApp < Sinatra::Base
    enable :raise_errors
    disable :dump_errors
    disable :show_exceptions

    post '/api/1/register_a_new_service' do
      service_id = TresfiestasFake.services.size + 100
      service = JSON.parse(request.body.read)["service"]
      if service["name"].to_s.empty?
        status 400
        {:error_messages => ["Name can't be blank"]}.to_json
      else
        TresfiestasFake.services[service_id.to_s] = service
        status 201
        headers 'Location' => "#{BASE_URL}/api/1/services/#{service_id}"
        {}.to_json
      end
    end

    get '/api/1/services/:service_id' do |service_id|
      if service = TresfiestasFake.services[service_id.to_s]
        {"service" => service}.to_json
      else
        status 404
        {}.to_json
      end
    end

    put '/api/1/services/:service_id' do |service_id|
      service = TresfiestasFake.services[service_id.to_s]
      update_params = JSON.parse(request.body.read)["service"]
      if update_params.key?("name") && update_params["name"].to_s.empty?
        status 400
        {:error_messages => ["Name can't be blank"]}.to_json
      else
        service.merge!(update_params)
        {}.to_json
      end
    end

    delete '/api/1/services/:service_id' do |service_id|
      TresfiestasFake.services.delete(service_id.to_s)
      {}.to_json
    end

    post '/api/1/invoices/:service_account_id' do |service_account_id|
      invoice_params = JSON.parse(request.body.read)["invoice"]
      unless invoice_params['total_amount_cents'].is_a?(Fixnum)
        status 400
        return {:error_messages => ["Total Amount Cents must be an integer"]}.to_json
      end
      if invoice_params["line_item_description"].to_s.empty?
        status 400
        return {:error_messages => ["Line item description can't be blank"]}.to_json
      end
      if invoice_params['total_amount_cents'] < 0
        status 400
        return {:error_messages => ["Total amount cents must be greater than or equal to 0"]}.to_json
      end
      TresfiestasFake.invoices << invoice_params.merge('service_account_id' => service_account_id.to_i)
      {}.to_json
    end

    post '/api/1/messages/:service_account_id' do |service_account_id|
      message_params = JSON.parse(request.body.read)["message"]

      if message_params['subject'].to_s.empty?
        status 400
        return {:error_messages => ["Subject can't be blank."]}.to_json
      end

      unless ['status', 'notification', 'alert'].include? message_params['message_type']
        status 400
        return {:error_messages => ['Message type must be one of: status, notification or alert']}.to_json
      end

      TresfiestasFake.status_messages << message_params
      {}.to_json
    end


    post '/api/1/provisioned_service_messages/:provisioned_service_id' do |provisioned_service_id|
      message_params = JSON.parse(request.body.read)["message"]

      if message_params['subject'].to_s.empty?
        status 400
        return {:error_messages => ["Subject can't be blank."]}.to_json
      end

      unless ['status', 'notification', 'alert'].include? message_params['message_type']
        status 400
        return {:error_messages => ['Message type must be one of: status, notification or alert']}.to_json
      end

      TresfiestasFake.status_messages << message_params.merge('provisioned_service_id' => provisioned_service_id.to_i)
      {}.to_json
    end

  end

end
