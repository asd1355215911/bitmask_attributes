require 'test_helper'

[
  CampaignWithNull,
  CampaignWithoutNull,
  SubCampaignWithNull,
  SubCampaignWithoutNull
].each do |klass|

  Class.new(ActiveSupport::TestCase) do

    def teardown
      klass.destroy_all
    end

    def test_defined_values
      assert_equal klass.values_for_medium, [:web, :print, :email, :phone]
    end

    def test_assign_single_value
      assert_stored klass.new(medium: :web), :web
    end

    def test_assign_multiple_values
      assert_stored klass.new(medium: [:web, :print]), :web, :print
    end

    def test_add_single_value
      model = klass.new(medium: [:web, :print])
      assert_stored model, :web, :print
      model.medium << :phone
      assert_stored model, :web, :print, :phone
    end

    def test_duplicate_values
      model = klass.new(medium: [:web, :print])
      assert_stored model, :web, :print
      model.medium << :phone
      assert_stored model, :web, :print, :phone
      model.medium << :phone
      assert_stored model, :web, :print, :phone
      model.medium << "phone"
      assert_stored model, :web, :print, :phone
      assert_equal model.medium.select{ |value| value == :phone }.size, 1
      assert !model.medium.any?{ |value| value == "phone" }
    end

    def test_assign_new_values
      model = klass.new(medium: [:web, :print])
      assert_stored model, :web, :print
      model.medium = [:phone, :email]
      assert_stored model, :phone, :email
    end

    def test_assign_raw_values
      model = klass.new
      model.medium = 3
      assert_stored model, :web, :print
      model.medium = 0
      assert_empty model.medium
    end

    def test_save_and_retrieve
      model = klass.new(medium: [:web, :print])
      assert_stored model, :web, :print
      assert model.save!
      assert_stored klass.find(model.id), :web, :print
    end

    def test_unsupported_raises
      assert_raises(ArgumentError) do
        klass.new(medium: [:web, :print, :this_will_fail])
      end
      model = klass.new(medium: :web)
      assert_raises(ArgumentError){ model.medium << :this_will_fail_also }
      assert_raises(ArgumentError){ model.medium = [:so_will_this] }
      assert_stored model, :web
    end

    def test_unsupported_raw_values
      model = klass.new(medium: :web)
      size = klass.values_for_medium.size
      assert_raises(ArgumentError){ model.medium = 2 ** size }
      assert_raises(ArgumentError){ model.medium = -1 }
    end

    def test_bitmask_for
      assert_equal klass.bitmask_for_medium(:web), 1
      assert_equal klass.bitmask_for_medium(:print), 2
      assert_equal klass.bitmask_for_medium(:web, :print), 3
      assert_equal klass.bitmask_for_medium(:web, :print, ''), 3
      assert_equal klass.bitmask_for_medium('web'), 1
      assert_equal klass.bitmask_for_medium('print'), 2
      assert_equal klass.bitmask_for_medium('web', 'print'), 3
      assert_raises(ArgumentError) do
        klass.bitmask_for_medium(:web, :and_this_isnt_valid)
      end
    end

    def test_for_bitmask
      assert_equal klass.medium_for_bitmask(1), [:web]
      assert_equal klass.medium_for_bitmask(2), [:print]
      assert_equal klass.medium_for_bitmask(3), [:web, :print]
      assert_raises(ArgumentError) do
        klass.medium_for_bitmask(:this_isnt_valid)
      end
    end

    def test_non_standard_attribute_name
      model = klass.create!(Legacy: [:upper, :case])
      assert_equal klass.find(model.id).Legacy, [:upper, :case]
    end

    def test_ignore_blanks
      assert_stored klass.new(medium: [:web, :print, '']), :web, :print
    end

    def test_attribute_for_value?
      model = klass.new medium: [:web, :print]
      assert model.medium_for_web?
      assert model.medium_for_print?
      assert !model.medium_for_email?
    end

    def test_attribute?
      model = klass.new medium: [:web, :print]
      assert model.medium?
      assert model.medium?(:web)
      assert model.medium?(:print)
      assert !model.medium?(:email)
      assert model.medium?(:web, :print)
      assert !model.medium?(:web, :email)
      assert !klass.new.medium?
    end

    def test_nulls_for_zero_value
      model = klass.create!
      assert_equal klass.with_allow_zero(:none), [model]
    end

    def test_allow_zero_in_values_without_changing_result
      assert_equal klass.bitmask_for_allow_zero(:none), 0
      assert_equal klass.bitmask_for_allow_zero(:one, :two, :three, :none), 7

      model = klass.create!(allow_zero: :none)
      assert_equal model.allow_zero, []
      assert_equal klass.with_allow_zero(:none), [model]
      assert_equal klass.with_any_allow_zero(:none, :one), [model]
      assert_equal klass.without_allow_zero(:none), []
      assert_equal klass.with_exact_allow_zero(:none), [model]

      model.update! allow_zero: :none
      assert_equal model.allow_zero, []
      assert model.allow_zero?(:none)

      model.update! allow_zero: [:one,:none]
      assert_equal model.allow_zero, [:one]
      assert_equal klass.with_allow_zero(:none), []
      assert_equal klass.without_allow_zero(:none), [model]
      assert_equal klass.with_exact_allow_zero(:none, :one), []
    end

    def test_scopes
      models = [
        klass.create!(medium: [:web, :print]),
        klass.create!,
        klass.create!(medium: [:web, :email]),
        klass.create!(medium: :web),
        klass.create!(medium: [:web, :print, :email]),
        klass.create!(medium: [:web, :print, :email, :phone]),
        klass.create!(medium: [:email, :phone])
      ]

      assert_equal klass.with_medium, models.select(&:medium?)
      assert_equal klass.with_any_medium, models.select(&:medium?)
      assert_equal klass.with_medium(:print), models.select{ |model| model.medium?(:print) }
      assert_equal klass.without_medium, models.select{ |model| !model.medium? }
      assert_equal klass.no_medium, models.select{ |model| !model.medium? }

      assert_equal(
        klass.with_any_medium(:print, :email),
        models.select{ |model| model.medium?(:print) || model.medium?(:email) }
      )
      assert_equal(
        klass.with_medium(:web, :print),
        models.select{ |model| model.medium?(:web, :print) }
      )
      assert_equal(
        klass.with_medium(:web, :email),
        models.select{ |model| model.medium?(:web, :email) }
      )
      assert_equal(
        klass.without_medium(:print),
        models.select{ |model| !model.medium?(:print) }
      )
      assert_equal(
        klass.without_medium(:web, :print),
        models.select{ |model| !model.medium?(:web) && !model.medium?(:print) }
      )
      assert_equal(
        klass.without_medium(:print, :phone),
        models.select{ |model| !model.medium?(:print) && !model.medium?(:phone) }
      )
      assert_equal(
        klass.with_exact_medium(:web),
        models.select{ |model| model.medium == [:web] }
      )
      assert_equal(
        klass.with_exact_medium(:web, :print),
        models.select{ |model| model.medium == [:web, :print] }
      )
      assert_equal(
        klass.with_exact_medium,
        models.select{ |model| model.medium == [] }
      )
    end

    protected

    def assert_stored(record, *values)
      assert_equal record.medium, values
      assert_equal record.medium.to_i, klass.bitmask_for_medium(*values)
    end

  end.send(:define_method, :klass){ klass }

end
