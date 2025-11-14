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