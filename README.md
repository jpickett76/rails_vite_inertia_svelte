This post was inspired, and partially copied from Andrew's post on his blog, which you can find here: https://hashnode.com/post/deploy-a-svelteinertiarails-app-to-heroku-ckz6daabm0sqtghs1808cewbz, and Stefan's post on his blog, which you can find here: https://stefanwienert.net/deploying-a-rails-7-app-to-heroku-with-vite-and-svelte/

# Rails 7 + Svelte + Intertia + Heroku
I will be using the same example as Stefan, and will be using a docker-compose.yml to get my postgres instance running locally, as well as using the same example as Andrew, and will be deploying to Heroku. 

### Demo
You can find the demo here: https://rails-vite-inertia-svelte.herokuapp.com/


## Getting Started
What I have installed on my machine is the following, You may have different versions, and that may be ok.:
* Ruby 3.1.2  -- Inslled using rbenv -- https://github.com/rbenv/rbenv
* Rails 7.0.4  
* Node 19.3.0  -- https://docs.npmjs.com/downloading-and-installing-node-js-and-npm
* Docker Desktop 4.15.0  -- https://www.docker.com/products/docker-desktop

## Creating the Rails App
```
rails new your-app-name --skip-javascript --skip-asset-pipeline --database=postgresql
```
We need to have the --database=postgresql flag as a postgres database is what is required to deploy to heroku.

### Adding Svelte and Intertia
```
bundle add 'inertia_rails' 'vite_rails'
```
This will create a folder for your frontend, a default vite.config.ts, and update your application.html.erb, as well as setting up our initial package.json. From here, we still need to add some more packages:


```
npm install -D axios svelte @sveltejs/vite-plugin-svelte @inertiajs/inertia @inertiajs/inertia-svelte @inertiajs/progress
```
```
npm i -D vite-plugin-full-reload
```

Axios is used by Intertia under the hood, and we need to make sure we avoid getting caught without CSRF tokens in our requests, svelte @sveltejs/vite-plugin-svelte @intertiajs/inertia-svelte all deal with the svelte integration, and @intertiajs/inertia @intertiajs/progress are for our inertia integration and a progress bar so if things take a bit longer than expected to be returned from the server the user will know it is loading.

Next, grab the application.js in the newly crateed frontend folder and change it to:

Full **your-app-name/app/frontend/entrypoints/application.js**

```javascript
import axios from 'axios'

import { createInertiaApp } from '@inertiajs/inertia-svelte'
import { InertiaProgress } from '@inertiajs/progress'

const pages = import.meta.glob('../pages/**/*.svelte')

const csrfToken = document.querySelector('meta[name=csrf-token]').content
axios.defaults.headers.common['X-CSRF-Token'] = csrfToken

InertiaProgress.init()

createInertiaApp({ 
  resolve: name => pages[`../pages/${name}.svelte`](),
  setup({ el, App, props }) {
    new App({ target: el, props })
  },
})
```
which sets up all of the above (i.e. CSRF tokens, progress bar, vite/svelte configuration). Continuing on from Stefan's example, open up vite.config.ts and change it to

Full **your-app-name/vite.config.ts**
```ts
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  resolve: {
    dedupe: ['axios']
  },
  plugins: [
    RubyPlugin(),
    svelte({
      experimental: {
        prebundleSvelteLibraries: true
      }
    })
  ]
})
```

After all this, you may need to make sure the package.json has the following in the scripts section:

Full **your-app-name/package.json**
```json
{
  "type": "module",
  "devDependencies": {
    "@inertiajs/inertia": "^0.11.1",
    "@inertiajs/inertia-svelte": "^0.8.0",
    "@inertiajs/progress": "^0.2.7",
    "@sveltejs/vite-plugin-svelte": "^2.0.2",
    "axios": "^1.2.2",
    "svelte": "^3.55.0",
    "vite": "^4.0.4",
    "vite-plugin-full-reload": "^1.0.5",
    "vite-plugin-ruby": "^3.1.3"
  },
  "dependencies": {
    "@inertiajs/inertia": "^0.11.1",
    "@inertiajs/inertia-svelte": "^0.8.0",
    "@inertiajs/progress": "^0.2.7",
    "svelte": "^3.46.6",
    "svelte-loader": "^3.1.2"
  }
}
```

## Setting up the Database With Docker
The next thing you'll want to do is: in the root of your project create a docker-compose.yml file and fill it with the following. This will make your postgres instance available at your localhost on port 5334, and connect to the postgres container on port 5432, the default listening port for postgres. 

FULL **your-app-name/docker-compose.yml**
```yml
version: "3.9"
services:
  db:
    image: "postgres:14.1"
    container_name: "your-app-name"
    environment:
      POSTGRES_PASSWORD: "postgres"
      POSTGRES_USER: "postgres"
    ports:
      - "5434:5432"
    volumes:
      - your-app-name:/var/lib/postgresql/data
volumes:
  your-app-name:
```

In your terminal run:
```cmd 
docker-compose up -d
```
This creates your docker container and runs it in the background. I like to leave off the -d so I can see the logs, but that's up to you.

From here, open up your database.yml and change the default portion to the following

Defalut Portion ONLY is  below **config/databasse.yml**
```yml 
default: &default
  adapter: postgresql
  encoding: unicode
  # For details on connection pooling, see Rails configuration guide
  # https://guides.rubyonrails.org/configuring.html#database-pooling
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: postgres
  password: postgres
  host: localhost
  port: 5434
```

Now in the termial, from the root directory of your appliation run the following:
```
rake db:create
```

## Setting up a Model

```
rails g model user email:string name:string
```
This will create a user model and migration to match. Now you can run 

```
rails db:migrate
```
Creates the users table. Once that is done we can run the console and create a user

```
rails c
User.create(name: "Darth Vader", email: "happyvader@fluffybunny.com")
```

## Setting up the Frontend
Update your routes file and add a route for a root path that will point at our home controller

FULL **your-app-name/config/routes.rb**
```rb
# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"
end
```

Run ```rails g controller home``` to generate your controller to handle the views. Change the controller to look like the following:

FULL **your-app-name/app/controllers/home_controller.rb**
```rb
# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    render inertia: 'HomePage', props: {
      user: User.first
    }
  end
end
```

The render inertia is where all of that sweet sweet inertia goodness comes into play. Those props will be handed into your svelte component as you would expect them to in any other svelte(kit) application! Now in your frontend directory, create a pages directory. From your terminal you can run:

```
mkdir mkdir app/frontend/pages
```

Create a HomePage.svelte file in the pages directory. This is where we will be rendering our user data.
```
touch app/frontend/pages/HomePage.svelte
```
***your-app-name/app/frontend/pages/HomePage.svelete
```svelte
<script>
  export let user
</script>

<h1>Hello {user.email}</h1>
<input type="text" bind:value="{user.email}" placeholder="Enter your name" />

<style>
 h1 {
  font-size: 45px;
  padding: 1.5rem;
 }

 input {
   padding: 1rem;
   border-radius: 0.5rem;
   background-color: rgb(240, 240, 240);
   color: rgb(63, 63, 63);
 }
</style>
```


## Testing Locally
Make sure docker is still running, and then in your terminal, from the root of your application run:
```
rails s
```
Then you can navigate to http://localhost:3000 and see your user data rendered in the browser. Make sure you have your docker container running as well, or you won't be able to connect to the database. 

## Deploying to Heroku

Make sure whatever you type into the input is updating the value for Mister Skywalker (at least on the front end)!

From here we get into the actual deploy to heroku:

I'm assuming you already have a heroku account, but if not you should probably sign up now, and download their cli.

Then once you have done that, in your terminal you'll want to create your app and give it a name that actually makes sense, and add the nodejs buildpack and the ruby buildpack. Make sure nodejs is first, otherwise you will end up with a build error.
```
heroku create your_app_name
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/ruby
heroku config:set NPM_CONFIG_INCLUDE='dev' YARN_PRODUCTION=false
heroku config:set NPM_CONFIG_PRODUCTION=false YARN_PRODUCTION=false
```
Then you'll want to add the postgres addon to your heroku app:
```
heroku addons:create heroku-postgresql:hobby-dev
```
Check that it set the heroku remote correctly with 
```
git remote -v
```

Now we need to add heroku's platform to our gemfile.lock. In your terminal run:
```
bundle lock --add-platform x86_64-linux
```

Make sure you commit 
Head to your heroku account, and find your newly created app. Then go to settings, and add a ruby buildpack to the app. You're almost there!

Finally, after saving and committing all of this in git, you can send it on it's way with git push heroku main

Once this is done pushing, run 
```
heroku run rake db:migrate 
heroku run rails c
User.create(name: "Darth Vader", email: "happyvader@fluffybunnyhugs.com")
exit
```
to get the migrated database values up and going, and as the last thing, run heroku open to open your app!

Voila! You should now have a working Svelte/Inertia/Rails app deployed on Heroku!