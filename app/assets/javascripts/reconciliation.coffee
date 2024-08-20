# template = (item) -> item.text + ' (' + item.score + ', ' + item.id + ') '
# template_selection = (item) -> item.text + ' (' +  item.id + ') '

# jQuery(document).on 'turbolinks:load', ->
#   $('#uri').select2
#     ajax: {
#       url: 'http://localhost:3003/recon' # 'http://api.artsdata.ca/recon'
#       data: (params) ->
#         { 
#           query: params.term
#         }
#       dataType: 'json'
#       delay: 500
#       processResults: (data, params) ->
#         {
#           results: _.map(data.result, (el) ->
#             {
#               text: el.name
#               id:  el.id 
#               score: el.score
#             }
#           )
#         }
#       cache: true
#     }
#     escapeMarkup: (markup) -> markup
#     minimumInputLength: 2
#     templateResult: template
#     templateSelection: template_selection