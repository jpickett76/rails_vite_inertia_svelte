NB: This post takes heavy inspiration from Stefan Buhrmester's article, with the addition of deployment to Heroku and a few extra little tidbits.

For this you will also need to download Docker Desktop, as I will be using a simple docker-compose.yml to get my postgres instance running.

To start of with a new rails 7 app, make sure you have the latest rails version (7.0.1 for me currently) and then run

```
rails new your-app-name --skip-javascript --skip-asset-pipeline --database=postgresql
```


We need to have the --database=postgresql flag as a postgres database is what is required to deploy to heroku.

From here, as per Stefan, add intertia_rails and vite_rails with
```
bundle add 'inertia_rails' 'vite_rails'
```
and run the vite installer:
```
bundle exec vite install
```
which will create a folder for your frontend, a default vite.config.ts, and update your application.html.erb, as well as setting up our initial package.json. From here, we still need to add some more packages:

```
npm install -D axios svelte @sveltejs/vite-plugin-svelte @inertiajs/inertia @inertiajs/inertia-svelte @inertiajs/progress
```

Axios is used by Intertia under the hood, and we need to make sure we avoid getting caught without CSRF tokens in our requests, svelte @sveltejs/vite-plugin-svelte @intertiajs/inertia-svelte all deal with the svelte integration, and @intertiajs/inertia @intertiajs/progress are for our inertia integration and a progress bar so if things take a bit longer than expected to be returned from the server the user will know it is loading.

Next, grab your application.js, and change it to
```
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

```
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
Now we can move on to the next piece of this puzzle, and deviate from the other article (other than the first command where we installed rails with --database=postgresql as well).

The next thing you'll want to do is: in the root of your project create a docker-compose.yml file and fill it with

```
version: "3.9"
services:
  db:
    image: "postgres:14.1"
    container_name: "your-app-name"
    environment:
      POSTGRES_PASSWORD: "postgres"
    ports:
      - "5432:5432"
    volumes:
      - your-app-name:/var/lib/postgresql/data
volumes:
  your-app-name:
```

and then run
```
docker-compose up -d
```

to create your docker container and run it in the background.

From here, open up your database.yml and change the values in the development: section to be

```
host: localhost
database: your-app-name-development
username: postgres
password: postgres
port: 5432
```

and then open the container with your cli (I typically just go to docker-desktop and open it from the container itself:


Once in there, run
```
psql -U postgres
```

and then once in the shell, run

'''
create database your-test-app_development;
create database your-test-app_test;
exit;
'''

Congrats! You have a db set up. Now you're back in mostly familiar rails territory. To verify this is working, in your terminal run

```
rails g migration create_users
```

to create a users table, and create a User model in models/user.rb and 
fill it with

```
# frozen_string_literal: true

class User < ApplicationRecord
end
```

In the migration you created, fill it with

```
# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :name

      t.timestamps
    end
  end
end

```
to give your user a name you can call them by.

Head back to your terminal and run

```
rails db:migrate
```

wait for the migration, and run

```
rails c
```

to get the rails console, then create a user with

```
User.create(name: "Darth Vader")
```
In your config/routes.rb, fill it with

```
# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"
end
```
to create an initial home page for the rails app. From here, create an app/controllers/home_controller.rb, and fill it with
```
# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    render inertia: 'HomePage', props: {
      user: User.first
    }
  end
end
```

The render inertia is where all of that sweet sweet inertia goodness comes into play. Those props will be handed into your svelte component as you would expect them to in any other svelte(kit) application! Now in your frontend directory, create a pages directory, and put a HomePage.svelte component in there, filling that with something simple and hideous (or beautiful):

```
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

Make sure whatever you type into the input is updating the value for Mister Skywalker (at least on the front end)!

From here we get into the actual deploy to heroku:

I'm assuming you already have a heroku account, but if not you should probably sign up now, and download their cli.

Then once you have done that, in your terminal you'll want to create your app and give it a name that actually makes sense, and add the nodejs buildpack:
```
heroku create your_app_name
heroku buildpacks:add heroku/nodejs
```
Check that it set the heroku remote correctly with 
```
git remote -v
```
Head to your heroku account, and find your newly created app. Then go to settings, and add a ruby buildpack to the app. You're almost there!

Finally, after saving and committing all of this in git, you can send it on it's way with git push heroku main

Once this is done pushing, run 
```
heroku run rails db:migrate 
```
to get the migrated database values up and going, and as the last thing, run heroku open to open your app!

Voila! You should now have a working Svelte/Inertia/Rails app deployed on Heroku!