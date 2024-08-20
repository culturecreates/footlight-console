//= require jquery
//= require jquery.turbolinks
//= require rails-ujs
//= require turbolinks
//= require bulmahead.bundle
//= require underscore
//= require select2
//= require reconciliation
//= require_tree .



$(document).on('turbolinks:load', function() {

  document.addEventListener("turbolinks:before-cache", function() {
    //hide any flash notices
    $('.flash-notification').hide();
  })


});
