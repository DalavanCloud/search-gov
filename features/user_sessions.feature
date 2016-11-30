Feature: User sessions

  @javascript
  Scenario: Already logged-in user visits login page
    Given I am logged in with email "affiliate_admin@fixtures.org"
    And I go to the login page
    Then I should see "Contact Information"
    When I sign out
    Then I should be on the login page

  Scenario: User has trouble logging in
    When I log in with email "not@valid.gov" and password "fail"
    Then I should see "Login failed due to invalid username and/or password."

  Scenario: Affiliate admin should be on the site home page upon successful login
    Given I am on the login page
    Then I should see the browser page titled "DigitalGov Search Login"
    And I log in with email "affiliate_admin@fixtures.org" and password "test1234!"
    Then I should be on the new site page

  Scenario: Affiliate manager should be on the site home page upon successful login
    When I log in with email "affiliate_manager@fixtures.org" and password "test1234!"
    Then I should be on the gobiernousa's Dashboard page

  Scenario: Affiliate manager with not approved status should not be able to login
    When I log in with email "affiliate_manager_with_not_approved_status@fixtures.org" and password "test1234!"
    Then I should not see "Admin Center"

  Scenario: User attempts too many invalid logins
    Given the following Users exist:
      | contact_name | email            | password  | failed_login_count |
      | Jane         | jane@example.com | test1234! | 10                 |
    When I log in with email "jane@example.com" and password "wompwomp"
    Then I should see "Consecutive failed logins limit exceeded, account has been temporarily disabled."

  Scenario: User's password is more than 90 days old
    Given the following Users exist:
      | contact_name | email            | password  | password_updated_at |
      | Jane         | jane@example.com | test1234! | 2015-01-01          |
    When I log in with email "jane@example.com" and password "test1234!"
    Then I should be on the login page
    And I should see "Looks like it's time to change your password! Please check your email for the password reset message we just sent you. Thanks!"
    And "jane@example.com" should receive the "password_reset_instructions" mandrill email
