require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/reloader'
require 'padrino-helpers'
require 'will_paginate'
require 'will_paginate/active_record'
require 'securerandom'

module TonBot
  class AdminApp < Sinatra::Base
    register Padrino::Helpers
    
    configure do
      set :views, File.expand_path('../../views', __FILE__)
      enable :logging
    end

    configure :development do
      register Sinatra::Reloader
    end

    # Configure WillPaginate
    set :per_page, 20

    # Session configuration with secure defaults
    use Rack::Session::Cookie,
      key: 'ton_bot_admin.session',
      path: '/admin',
      secret: ENV['ADMIN_SECRET'],
      same_site: :lax,
      expire_after: 86400, # 24 hours
      httponly: true,
      secure: false # Set to true in production with HTTPS

    # Helper methods
    helpers do
      def authenticate!
        unless session[:admin]
          session[:return_to] = request.path_info
          redirect '/admin/login'
        end
      end

      def admin?
        session[:admin]
      end

      def paginate(collection)
        @page = (params[:page] || 1).to_i
        collection.paginate(page: @page, per_page: settings.per_page)
      end
    end

    # Before filter
    before do
      pass if request.path_info == '/admin/login'
      # authenticate!
    end

    # Routes
    get '/login' do
      if session[:admin]
        redirect '/admin'
      else
        erb :'admin/login', layout: false
      end
    end

    post '/login' do
      if params[:token] == ENV['ADMIN_TOKEN']
        session[:admin] = true
        redirect session.delete(:return_to) || '/admin'
      else
        @error = 'Invalid token'
        erb :'admin/login', layout: false
      end
    end

    get '/logout' do
      session.clear
      redirect '/admin/login'
    end

    # Dashboard
    get '/' do
      @stats = {
        total_documents: RawDocument.count,
        processed_documents: RawDocument.where(processed: true).count,
        total_embeddings: Embedding.count,
        sidekiq_stats: Sidekiq::Stats.new
      }
      @recent_documents = RawDocument.order(created_at: :desc).limit(10)
      erb :'admin/dashboard'
    end

    # Documents
    get '/documents' do
      @documents = paginate(RawDocument.order(created_at: :desc))
      erb :'admin/documents/index'
    end

    get '/documents/:id' do
      @document = RawDocument.find(params[:id])
      erb :'admin/documents/show'
    end

    post '/documents/:id/reprocess' do
      document = RawDocument.find(params[:id])
      document.update(processed: false)
      EmbeddingProcessorJob.perform_async(document.id)
      redirect "/admin/documents/#{document.id}"
    end

    # Embeddings
    get '/embeddings' do
      @embeddings = paginate(Embedding.order(created_at: :desc))
      erb :'admin/embeddings/index'
    end

    get '/embeddings/:id' do
      @embedding = Embedding.find(params[:id])
      erb :'admin/embeddings/show'
    end

    # Sidekiq Stats
    get '/sidekiq-stats' do
      @stats = Sidekiq::Stats.new
      @queues = Sidekiq::Queue.all
      @workers = Sidekiq::Workers.new
      erb :'admin/sidekiq_stats'
    end

    # API endpoints for AJAX updates
    get '/api/stats' do
      content_type :json
      {
        total_documents: RawDocument.count,
        processed_documents: RawDocument.where(processed: true).count,
        total_embeddings: Embedding.count,
        sidekiq: {
          processed: Sidekiq::Stats.new.processed,
          failed: Sidekiq::Stats.new.failed,
          enqueued: Sidekiq::Stats.new.enqueued,
          workers: Sidekiq::Workers.new.size
        }
      }.to_json
    end

    # Error handling
    not_found do
      erb :'admin/404'
    end

    error do
      erb :'admin/500'
    end
  end
end
