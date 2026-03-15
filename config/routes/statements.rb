  # Common actions that operate on a specific statement
  concern :statement_member_actions do
    patch ':id/review_statement',
          to: 'statements#review_statement',
          as: :review_statement

    patch ':id/save_manual_statement',
          to: 'statements#save_manual_statement',
          as: :save_manual_statement

    patch ':id/flag_statement',
          to: 'statements#flag_statement',
          as: :flag_statement_patch

    get ':id/flag_statement',
        to: 'statements#flag_statement',
        as: :flag_statement

    get ':id/activate',
        to: 'statements#activate',
        as: :activate_statement

    get ':id/activate_individual',
        to: 'statements#activate_individual',
        as: :activate_individual_statement

    get ':id/deactivate_individual',
        to: 'statements#deactivate_individual',
        as: :deactivate_individual_statement

    get ':id/reconnect_feed',
        to: 'statements#reconnect_feed',
        as: :reconnect_feed_statement
  end

  ############################################################
  # Statements
  ############################################################

  # Statements represent RDF triples produced by the Condenser.
  # These are intentionally non-RESTful moderation actions.

  scope :statements do

    # Routes that require a statement ID
    scope constraints: { id: /\d+/ } do
      concerns :statement_member_actions
    end

    # Manual editing interface
    get 'edit_manual_statement',
        to: 'statements#edit_manual_statement',
        as: :edit_manual_statement

    get 'cancel_edit_manual_statement',
        to: 'statements#cancel_edit_manual_statement',
        as: :cancel_edit_manual_statement
  end