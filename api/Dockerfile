FROM ruby:3.3.4

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  libpq-dev \
  nodejs \
  git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app/api

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

RUN chmod +x bin/docker-start bin/render-release

ENV RAILS_ENV=production
ENV RACK_ENV=production

EXPOSE 3000

CMD ["bin/docker-start"]
