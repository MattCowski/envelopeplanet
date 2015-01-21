angular.module 'angular', [
  'ngRoute', 
  'ngAnimate', 
  'ngSanitize',  
  'firebase', 
  'templates',
  'ui.bootstrap.carousel' ,
  'ui.bootstrap.tpls',
  'ui.calendar', 
  'mgcrea.ngStrap.affix', 
  'mgcrea.ngStrap.helpers.dimensions',
  # 'ui.mask',
  'ui.bootstrap.typeahead',
  'ui.bootstrap.tabs',
  'ui.bootstrap.progressbar',
  'ui.bootstrap.dropdown',
  'ui.bootstrap.datepicker',
  'ui.bootstrap.collapse',
  'ui.bootstrap.buttons',
  'ui.bootstrap.accordion',
  'mgcrea.ngStrap.popover',
  'mgcrea.ngStrap.tooltip', 
  'mgcrea.ngStrap.modal', 
  'mgcrea.ngStrap.navbar', 
  'mgcrea.ngStrap.alert', 
  'angulartics', 'angulartics.google.analytics', 'angulartics.scroll',
  # or rename with gulp-ng-annotate to solve conflict
  # https://github.com/mgcrea/angular-strap/issues/521 
  # 'twilio-client-js'
  # 'angularFileUpload', 
]
  .config ($routeProvider, $httpProvider, $locationProvider) ->
    $locationProvider.html5Mode(false)

    $routeProvider
      .when '/',
        templateUrl: "main/home.html"
        controller: "HomeCtrl"

      .otherwise
        redirectTo: '/'
  .constant('FIREBASE_URL', "https://envelopeplanet.firebaseio.com/")
  .factory('ENVIROMENT', ($location) ->
    if $location.host() is "localhost"
      # return 'http://localhost:9000/'
      return 'http://d744f9c.ngrok.com/'
    else
      return 'https://envelopeplanet.herokuapp.com/'
    
  )
  .run ($rootScope, $routeParams, $location, $anchorScroll, Auth) ->   

    $rootScope.$on '$routeChangeError', (event, next, previous, error) ->
      if error is "AUTH_REQUIRED"
        console.log event, next, previous, error
        $location.path "/login"
 
    
  .factory "Requests", (FIREBASE_URL, $firebase) ->
    ref = new Firebase(FIREBASE_URL)
    $firebase(ref.child("requests"))

  .factory "Claim", (FIREBASE_URL, $firebase) ->
    ref = new Firebase(FIREBASE_URL)
    $firebase(ref.child("claim"))

  .factory "Auth", ($modal, Requests, Claim, $firebase, FIREBASE_URL, $firebaseAuth, $rootScope, $timeout, $location) ->
    ref = new Firebase(FIREBASE_URL)
    auth = $firebaseAuth(ref)

    Auth =
      user: null
      $unauth: auth.$unauth
      $onAuth: auth.$onAuth
      $authWithCustomToken: auth.$authWithCustomToken
      $authWithPassword: auth.$authWithPassword
      $createUser: auth.$createUser
      
      createProfile: (user) ->
        profileData =
          # email: user[user.provider].email or ''
          md5_hash: user.md5_hash or ''
          roleValue: 10
        $firebase(ref.child('user_rooms').child(user.uid)).$set(user.uid, true)
        profileRef = $firebase(ref.child('profile').child(user.uid))
        if user.provider is 'twilio'
          phones = {}
          phones[user.auth.phone] = true
          profileRef.$update('phones', phones)
          
        angular.extend(profileData, $location.search())
        return profileRef.$update(profileData)
      requestCode: (phone) ->
        Requests.$set(phone, {uid: $rootScope.user.uid, phone: phone})

      confirmPhone: (code, phone) ->
        Claim.$set(phone, {uid: $rootScope.user.uid, phone: phone, code: code}) unless !code?

    auth.$onAuth (user) ->
      loginModal = $modal({template: 'main/modalLogin.html', show: false})
      if user
        Auth.user = {}
        angular.copy(user, Auth.user)
        Auth.user.profile = $firebase(ref.child('profile').child(Auth.user.uid)).$asObject()
        $rootScope.user = Auth.user
        # ref.child('profile/'+Auth.user.uid+'/online').set(true)
        # ref.child('profile/'+Auth.user.uid+'/online').onDisconnect().set(Firebase.ServerValue.TIMESTAMP)
        # ref.child('profile/'+Auth.user.uid+'/connections').push(true)
        # ref.child('profile/'+Auth.user.uid+'/connections').onDisconnect().remove()
        # ref.child('profile/'+Auth.user.uid+'/connections/lastDisconnect').onDisconnect().set(Firebase.ServerValue.TIMESTAMP)

      else
        if Auth.user and Auth.user.profile
          Auth.user.profile.$destroy()
        angular.copy({}, Auth.user)
        $rootScope.user = Auth.user



      # ref.child('.info/connected').on 'value', (snap) ->
      #   if snap.val() is true
      #     user = Auth.user.uid or 'unknown'
      #     ref.child('connections').push(user)
      #     ref.child('connections').onDisconnect().remove()

    return Auth




  .factory "Projects", (FIREBASE_URL, $firebase, $q) ->
    ref = new Firebase(FIREBASE_URL)
    projects = $firebase(ref.child('projects')).$asArray()
    Projects = 
      all: projects
      get: (projectId) ->
        return {} if projectId is true
        $firebase(ref.child('projects').child(projectId)).$asObject()
      create: (project) ->
        projects.$add(project)
      save: (project) ->
        projects.$save().then ->
          $firebase(ref.child('user_projects').child(project.creatorUID)).$push(projectRef.name())



  .factory "Profile", (FIREBASE_URL, $firebase, Projects, $q) ->
    ref = new Firebase(FIREBASE_URL)
    profile = (userId) ->
      sync: $firebase(ref.child("profile").child(userId))
      get: () ->
        $firebase(ref.child("profile").child(userId)).$asObject()
      # add: (userId) ->
      #   $firebase(ref.child("profile").child(userId))
      getProjects: () ->
        defer = $q.defer()
        $firebase(ref.child("user_projects").child(userId)).$asArray().$loaded().then (data) ->
          projects = {}
          i = 0

          while i < data.length
      #       value = data[i].$value 
            value = data[i].$id 
            projects[value] = Projects.get(value)
            i++
          defer.resolve projects
          return

        defer.promise
    profile


  .factory "Messages", (FIREBASE_URL, $firebase, $q) ->
    ref = new Firebase(FIREBASE_URL)
    # messages = $firebase(ref.child('messages').child(senderId)).$asArray()
    Messages = (senderId) ->
      # all: $firebase(ref.child('messages').child(senderId)).$asArray()
      create: (message) ->
        $firebase(ref.child('messages').child(senderId)).$asArray().$add(message)
        # .then (messageRef) ->
        #   $firebase(ref.child('user_messages').child(message.creatorUID)).$push(messageRef.name())
      get: () ->
        $firebase(ref.child('messages').child(senderId)).$asArray()
      # get: (postId) ->
      #   $firebase(ref.child('messages').child(postId)).$asObject()
      # comments: (postId) ->
      #   $firebase(ref.child('comments').child(postId)).$asArray()

  .factory "AllMessages", (FIREBASE_URL, Messages, $firebase, $q) ->
    ref = new Firebase(FIREBASE_URL)
    AllMessages =
      aggregate: (userId) ->
        defer = $q.defer()
        $firebase(ref.child("user_rooms").child(userId)).$asArray().$loaded().then (data) ->
          messages = {}
          i = 0
          while i < data.length
            senderId = data[i].$id 
            messages[senderId] = Messages(senderId).get()
            i++
          defer.resolve messages
          return

        defer.promise
    AllMessages


  .controller "HomeCtrl", ($popover, Auth, $scope, $routeParams, Profile, $firebase, FIREBASE_URL) ->
    return
  .controller "ProfileCtrl", ($popover, Auth, $scope, $routeParams, Profile, $firebase, FIREBASE_URL) ->
    uid = $routeParams.userId
    $scope.userId = $routeParams.userId
    $scope.profile = Profile(uid).get()
    Profile(uid).getProjects().then (projects) ->
      $scope.projects = projects
      return

    ref = new Firebase(FIREBASE_URL)
    $scope.addPhone = (phone) ->
      return if phone.trim() is ''
      # Profile(uid).sync.$update('phones',{'+12245552345': false})
      phone = '+1'+phone
      Auth.requestCode(phone) unless Auth.user.roleValue >= 20
      $firebase(ref.child("profile").child(uid).child('phones')).$set(phone, false).then ->
        $scope.newPhone = ''

    escapeEmailAddress = (email) ->
      return false  unless email      
      # Replace '.' (not allowed in a Firebase key) with ',' (not allowed in an email address)
      email = email.toLowerCase()
      email = email.replace(/\./g, ",")
      email
    $scope.addEmail = (email) ->
      return if email.trim() is ''
      # Profile(uid).sync.$update('emails',{'foo@email,com': false})
      $firebase(ref.child("profile").child(uid).child('emails')).$set(escapeEmailAddress(email), false).then ->
        $scope.newEmail = ''

    $scope.addAddress = (address) ->
      $firebase(ref.child("profile").child(uid).child('addresses')).$push(address)
    $scope.remove = (obj, key) ->
      delete obj[key]

    # comfirm-phone-popover:
    $scope.confirmPhone = (code, phone) ->
      Auth.confirmPhone(code, phone)

    return









  # use to prevent ngAnimate conflict with slider
  .directive 'disableNgAnimate', ['$animate', ($animate)->
    restrict: 'A'
    link: (scope, element)-> $animate.enabled false, element
  ]

  # from angular-ui 
  .controller "TypeaheadCtrl", ($scope, $http) ->
    $scope.selected = undefined
    $scope.asyncSelected = undefined
    
    # Any function returning a promise object can be used to load values asynchronously
    $scope.getLocation = (val) ->
      $http.get("http://maps.googleapis.com/maps/api/geocode/json",
        params:
          address: val
          sensor: false
      ).then (response) ->
        return response.data.results.map (item)->
          return item.formatted_address
        

