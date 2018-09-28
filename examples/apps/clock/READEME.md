bundle exec thin start --rackup config.ru -p 9292

### Cordova


##### Create app

```
cordova create clock com.example.clock Clock
cd clock
cordova platform add ios
cordova platform add android
cordova platform ls
```

add following to `www/index.html`

`<script src="https://code.jquery.com/jquery-3.2.1.min.js" integrity="sha256-hwg4gsxgFZhOsEEamdOYGBf13FyQuiTwlAQgxVSNgt4=" crossorigin="anonymous"></script>`

##### Build app

`cordova build ios --verbose`

##### Run app

`cordova run ios --verbose`

##### Remove app

`cordova platform remove ios`

##### Open in Xcode
`open -a Xcode platforms/ios`
