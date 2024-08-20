$(document).on('turbolinks:load', function() {

  document.addEventListener("turbolinks:before-cache", function() {
    //clean up before preview is cached
     $('.statement').removeClass("statement_open");
     $('.use-loading').removeClass('is-loading');
  })

  $('.statement').click(function(e) {
    let target = $(e.target);
    console.log(target)

    if ($(this).hasClass( "statement_open" )) {
      // do nothing if there is a text highlighted
      if (window.getSelection) {
        if (window.getSelection().toString() != '') {
          throw 'Abort click because text is highlighted';
        }
      }
      if (target.is('i') || target.is('a') || target.is('tag') || target.is('button') || target.is('textarea') || target.is('input') || target.is('select') || target.is('span') || target.is('div.card-content') || target.is('b')  || target.is('form')  || target.is('ul')) {
        // do nothing
      //  $(this).css( 'cursor', 'not-allowed' );
      //  $(this).prop('disabled', true);
      } else {
        $('.statement').removeClass("statement_open");
        $('.modal').removeClass('is-active');
        $('.linker_form').remove();
      }
    } else {
      if (target.is('a')  || target.is('span') || target.is('textarea')) {

        //do nothing because user clicked on an action or hyperlink.
        //  $(this).css( 'cursor', 'not-allowed' );
      } else {
        $('.statement').removeClass("statement_open");
        $('.linker_form').remove();
        $(this).addClass( "statement_open" );
      }
    }
  });

  $('.use-loading').click(function() {
    $(this).addClass('is-loading');
  });

  $('.open-modal-button').click(function() {
    let modalId = $(this).attr( 'id' ) + '-modal';
    $('#' + modalId).addClass( 'is-active' );
  });

  $('.modal-close').click(function() {
    $('.modal').removeClass('is-active');
  });

  $('.show-div-button').click(function() {
    let divId = $(this).attr( 'id' ) + '-div';
    $('#' + divId).show();
    $(this).hide();
  });

  $('.hide-div-button').click(function() {
    let divId = $(this).attr( 'id' ) + '-div';
    $('#add-' + divId).hide();
    let buttonId = $(this).attr( 'id' )
    $('#add-' + buttonId).show();
  });

});
