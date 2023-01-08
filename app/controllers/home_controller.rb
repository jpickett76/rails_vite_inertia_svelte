class HomeController < ApplicationController
  def index
    render inertia: 'HomePage', props: {
      user: User.first
    }
  end
end
