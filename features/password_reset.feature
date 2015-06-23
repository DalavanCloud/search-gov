Feature: Password Reset

  So that I can reset my password
  As an existing user
  I want to have a password reset email sent to me

  Scenario: I canot login because I cannot remember my account password
    Given I am on the login page
    And I follow "Forgot your password?"
    When I fill in "email" with "affiliate_admin@fixtures.org"
    And I press "Email me a link to reset my password"
    Then I should be on the password reset page
    And I should see "Instructions to reset your password have been emailed to you"
    And "affiliate_admin@fixtures.org" should receive the "password_reset_instructions" mandrill email
    When I visit the password reset page using the perishable token for "affiliate_admin@fixtures.org"
    When I fill in "Password" with "changed"
    And I press "Reset my password and log me in"
    Then I should see "Password successfully updated"
    And I should be on the user account page

  Scenario: I don't confirm my new password properly
    Given I am on the login page
    And I follow "Forgot your password?"
    When I fill in "email" with "affiliate_admin@fixtures.org"
    And I press "Email me a link to reset my password"
    Then "affiliate_admin@fixtures.org" should receive the "password_reset_instructions" mandrill email
    When I visit the password reset page using the perishable token for "affiliate_admin@fixtures.org"
    And I fill in "Password" with ""
    And I press "Reset my password and log me in"
    Then I should see "Password is too short"

  Scenario: Trying to reset the password of a user that doesn't exist
    Given I am on the login page
    And I follow "Forgot your password?"
    When I fill in "email" with "notarealuser@fixtures.org"
    And I press "Email me a link to reset my password"
    Then I should see "No user was found with that email address"
    And I should be on the password reset page
