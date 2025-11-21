# Footlight Console Frontend

This is the front end web application that connects to the Foolight Condenser via a RESTful API.

## License

All source code in this repository is available under the MIT License. See [LICENSE.md](LICENSE.md) for details.

## Getting started

To get started run the app on your local machine.

Clone the repo:
```
git clone https://github.com/culturecreates/footlight-console.git
cd footlight-console 
```

Install the needed gems:

```
bundle install
```

Set up the database:
```
rails db:create
rails db:migrate
rails db:seed  
```

Run the tests:
```
rails test
```

If the test suite passes, you'll be ready to run the app in a local server:

```
rails server -p 3001
```

Optional environment variables:
GOOGLE_MAPS_API - To use Google Maps API when adding a new Place address

SLACK_NOTIFICATION - To send notifications to Slack each time you login or add a comment to a flag.