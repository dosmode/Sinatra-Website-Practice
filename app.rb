require "sinatra"
require_relative "authentication.rb"
require "stripe"

set :publishable_key, "pk_test_xDS9v0c1IEmvkHsdji07ge8M"
set :secret_key, "sk_test_c1cGu9GOwWXSqlKrxtNYTNWv"

Stripe.api_key = settings.secret_key

# need install dm-sqlite-adapter
# if on heroku, use Postgres database
# if not use sqlite3 database I gave you
if ENV['DATABASE_URL']
  DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
else
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/app.db")
end

class Video
	include DataMapper::Resource

	property :id, Serial
	property :title, Text
	property :description, Text
	property :video_url, Text
	property :pro,Boolean, :default => false
	#fill in the rest
end

DataMapper.finalize
User.auto_upgrade!
Video.auto_upgrade!

#make an admin user if one doesn't exist!
if User.all(administrator: true).count == 0
	u = User.new
	u.email = "admin@admin.com"
	u.password = "admin"
	u.administrator = true
	u.save
end

def admin_only
	authenticate!
	if current_user.administrator == false
		redirect '/'
	end
end

get "/videos" do
	authenticate!
	if current_user.pro || current_user.administrator
		@videos =Video.all
	else
		@videos =Video.all(pro: false)
	end
	u=User.get(current_user.id)
	u.pro=true
	erb :videos

end

get '/videos/new' do
	admin_only
	erb :new_videos
end

post '/videos/create' do
	admin_only
			if params["title"] &&params["description"]&&params["video_url"]
			v= Video.new
			v.title=params["title"]
			v.description=params["description"]
			v.video_url=params["video_url"]
			v.pro = true if params["pro"]=="on"
			v.save
			end
end

get '/upgrade' do
	authenticate!
	if current_user.pro || current_user.administrator
		redirect '/'
	else 
		erb :pay
	end
  end
  
	post '/charge' do
		
		begin
	# Amount in cents
	@amount = 500
  
	customer = Stripe::Customer.create(
	  :email => 'customer@example.com',
	  :source  => params[:stripeToken]
	)
  
	charge = Stripe::Charge.create(
	  :amount      => @amount,
	  :description => 'Sinatra Charge',
	  :currency    => 'usd',
	  :customer    => customer.id
	)
	current_user.pro=true
	current_user.save

	erb :charge
	rescue 
		erb :error
	end
end

def youtube_embed(youtube_url)
	if youtube_url[/youtu\.be\/([^\?]*)/]
	  youtube_id = $1
	else
	  # Regex from # http://stackoverflow.com/questions/3452546/javascript-regex-how-to-get-youtube-video-id-from-url/4811367#4811367
	  youtube_url[/^.*((v\/)|(embed\/)|(watch\?))\??v?=?([^\&\?]*).*/]
	  youtube_id = $5
	end
  
	%Q{<iframe title="YouTube video player" width="640" height="390" src="https://www.youtube.com/embed/#{ youtube_id }" frameborder="0" allowfullscreen></iframe>}
  end
  
  youtube_embed('youtu.be/jJrzIdDUfT4')


#the following urls are included in authentication.rb
# GET /login
# GET /logout
# GET /sign_up

# authenticate! will make sure that the user is signed in, if they are not they will be redirected to the login page
# if the user is signed in, current_user will refer to the signed in user object.
# if they are not signed in, current_user will be nil

get "/" do
	erb :index
end