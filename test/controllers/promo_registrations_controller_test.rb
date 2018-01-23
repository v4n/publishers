require "test_helper"
require "webmock/minitest"

class PromoRegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include PromosHelper

  # NOTE: No longer passes since we need @promo_channels for these views to display
  # TO DO: Replace with integration tests that yield valid @promo_channels
  # test "#index renders :activate if publisher hasn't activated, otherwise renders :active" do
  #   publisher = publishers(:completed)
  #   sign_in publisher

  #   verify activate is rendered when promo inactive
  #   get promo_registrations_path
  #   assert_select("[data-test=promo-activate]")

  #   publisher.promo_enabled_2018q1 = true
  #   publisher.save

  #   # verify active is rendered when promo active
  #   get promo_registrations_path
  #   assert_select("[data-test=promo-active]")
  # end

  test "#index renders :over if promo not running" do
    publisher = publishers(:completed)
    sign_in publisher

    # expire the promo
    PromoRegistrationsController.any_instance.stubs(:promo_running?).returns(false)

    # verify over is rendered
    get promo_registrations_path
    assert_select("[data-test=promo-over]")
  end

  test "#create activates the promo, renders _activated_verified and enables promo for publisher" do
    publisher = publishers(:completed)
    sign_in publisher

    # verify create is rendered
    post promo_registrations_path
    assert_select("[data-test=promo-activated-verified]")

    # verify promo is enabled for publisher
    assert_equal publisher.promo_enabled_2018q1, true
  end

  test "#create does nothing and redirects to dashboard if promo not running" do
    publisher = publishers(:completed)
    sign_in publisher

    # expire the promo
    PromoRegistrationsController.any_instance.stubs(:promo_running?).returns(false)

    # verify :over is rendered
    post promo_registrations_path
    assert_select("[data-test=promo-over]")

    # verify publisher has not enabled promo
    assert_equal publisher.promo_enabled_2018q1, false
  end

  # NOTE: Same as above
  # TO DO: Replace with integration tests that yield valid @promo_channels
  # test "#create redirects to #index if publisher promo enabled, renders _active" do
  #   publisher = publishers(:completed)
  #   publisher.promo_enabled_2018q1 = true
  #   publisher.save

  #   sign_in publisher

  #   # verify _active is rendered
  #   post promo_registrations_path
  #   assert_select("[data-test=promo-active]")
  # end

  test "#create activates promo, renders _activated_unverified, doesn't engage registrar if publisher has no verified channels" do
    publisher = publishers(:default) # has one unverified channel
    sign_in publisher

    post promo_registrations_path

    # verify activated_unverified is loaded
    assert_select("[data-test=promo-activated-unverified]")

    # verify the promo has been enabled
    assert_equal publisher.promo_enabled_2018q1, true

    # TO DO: verify promo regsitrar was not used
  end

  test "publisher can activate/visit promo without being signed in using promo token from email" do
    publisher = publishers(:completed)

    # ensure we use token, not session for promo auth
    sign_out publisher

    promo_token = PublisherPromoTokenGenerator.new(publisher: publisher).perform

    # verify promo token auth takes you to _activate page
    url = promo_registrations_path(promo_token: promo_token)
    get url
    assert_response 200
    assert_select("[data-test=promo-activate]")

    # verify the above does not enable the promo
    assert_equal publisher.promo_enabled_2018q1, false

    # verify promo auth allows promo activation, takes publisher to _activated_verified
    post url
    publisher.reload
    assert_equal publisher.promo_enabled_2018q1, true
    assert_select("[data-test=promo-activated-verified]")

    # verify promo auth allows users to view active page once authorized
    get url
    assert_select("[data-test=promo-active]")

    # verify publisher is not must reauth to visit dashboard
    get home_publishers_path(publisher)
    assert_response 401 # Unauthorized # TO DO: See screen this takes you to, ideally dashboard
  end

  test "all requests with no promo_token in params or publisher in the session redirect homepage" do
    publisher = publishers(:completed)
    sign_out publisher

    # verify #create redirects to home if no token is supplied
    post promo_registrations_path
    assert_redirected_to root_path

    # verify #index redirects to home if no token is supplied
    get promo_registrations_path
    assert_redirected_to root_path    
  end
end




