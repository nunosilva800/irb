# frozen_string_literal: true
require "irb"

require_relative "helper"

module TestIRB
  class HelperMethodTestCase < TestCase
    def setup
      @verbosity = $VERBOSE
      $VERBOSE = nil
      save_encodings
      IRB.instance_variable_get(:@CONF).clear
    end

    def teardown
      $VERBOSE = @verbosity
      restore_encodings
    end

    def execute_lines(*lines, conf: {}, main: self, irb_path: nil)
      IRB.init_config(nil)
      IRB.conf[:VERBOSE] = false
      IRB.conf[:PROMPT_MODE] = :SIMPLE
      IRB.conf.merge!(conf)
      input = TestInputMethod.new(lines)
      irb = IRB::Irb.new(IRB::WorkSpace.new(main), input)
      irb.context.return_format = "=> %s\n"
      irb.context.irb_path = irb_path if irb_path
      IRB.conf[:MAIN_CONTEXT] = irb.context
      capture_output do
        irb.eval_input
      end
    end
  end

  class HelperMethodRegistrationTest < HelperMethodTestCase
    HELPER_METHODS_IVAR = :@helper_methods
    def setup
      super
      @original_helper_methods = IRB::HelperMethod.instance_variable_get(HELPER_METHODS_IVAR).dup
    end

    def teardown
      super
      IRB::HelperMethod.instance_variable_get(HELPER_METHODS_IVAR).each do |name, _|
        unless @original_helper_methods.key?(name)
          IRB::ExtendCommandBundle.undef_method(name)
        end
      end
      IRB::HelperMethod.instance_variable_set(HELPER_METHODS_IVAR, @original_helper_methods)
    end

    def test_helper_registeration
      STDIN.singleton_class.define_method :tty? do
        false
      end

      main = Object.new
      main.singleton_class.class_eval <<~RUBY
        class Foo < IRB::HelperMethod::Base
          category "Testing"
          description "This is a helper added for testing"

          def execute(arg)
            "from foo: \#{arg}"
          end
        end

        IRB::HelperMethod.register(:foo, Foo)
      RUBY

      IRB::ExtendCommandBundle.install_helper_methods

      out, err = execute_lines(
        "puts foo(100)"
      )

      assert_empty(err)
      assert_match("from foo: 100", out)

      out, err = execute_lines(
        "show_cmds"
      )

      assert_empty(err)
      assert_match(/Testing\n\s+foo\s+This is a helper added for testing/, out)
    ensure
      STDIN.singleton_class.remove_method :tty?
    end

    def test_helper_can_execute_block
      main = Object.new
      main.singleton_class.class_eval <<~RUBY
        class Foo < IRB::HelperMethod::Base
          def execute(&block)
            yield "from foo"
          end
        end

        IRB::HelperMethod.register(:foo, Foo)
      RUBY

      IRB::ExtendCommandBundle.install_helper_methods

      out, err = execute_lines(
        "foo { |s| puts s }"
      )

      assert_empty(err)
      assert_match("from foo", out)
    end
  end

  class MeasureTest < HelperMethodTestCase
    def test_measure
      conf = {
        PROMPT: {
          DEFAULT: {
            PROMPT_I: '> ',
            PROMPT_S: '> ',
            PROMPT_C: '> ',
            PROMPT_N: '> '
          }
        },
        PROMPT_MODE: :DEFAULT,
        MEASURE: false
      }

      c = Class.new(Object)
      out, err = execute_lines(
        "3\n",
        "measure\n",
        "3\n",
        "measure :off\n",
        "3\n",
        conf: conf,
        main: c
      )

      assert_empty err
      assert_match(/\A=> 3\nTIME is added\.\n=> nil\nprocessing time: .+\n=> 3\n=> nil\n=> 3\n/, out)
      assert_empty(c.class_variables)
    end

    def test_measure_keeps_previous_value
      conf = {
        PROMPT: {
          DEFAULT: {
            PROMPT_I: '> ',
            PROMPT_S: '> ',
            PROMPT_C: '> ',
            PROMPT_N: '> '
          }
        },
        PROMPT_MODE: :DEFAULT,
        MEASURE: false
      }

      c = Class.new(Object)
      out, err = execute_lines(
        "measure\n",
        "3\n",
        "_\n",
        conf: conf,
        main: c
      )

      assert_empty err
      assert_match(/\ATIME is added\.\n=> nil\nprocessing time: .+\n=> 3\nprocessing time: .+\n=> 3/, out)
      assert_empty(c.class_variables)
    end

    def test_measure_enabled_by_rc
      conf = {
        PROMPT: {
          DEFAULT: {
            PROMPT_I: '> ',
            PROMPT_S: '> ',
            PROMPT_C: '> ',
            PROMPT_N: '> '
          }
        },
        PROMPT_MODE: :DEFAULT,
        MEASURE: true
      }

      out, err = execute_lines(
        "3\n",
        "measure :off\n",
        "3\n",
        conf: conf,
      )

      assert_empty err
      assert_match(/\Aprocessing time: .+\n=> 3\n=> nil\n=> 3\n/, out)
    end

    def test_measure_enabled_by_rc_with_custom
      measuring_proc = proc { |line, line_no, &block|
        time = Time.now
        result = block.()
        puts 'custom processing time: %fs' % (Time.now - time) if IRB.conf[:MEASURE]
        result
      }
      conf = {
        PROMPT: {
          DEFAULT: {
            PROMPT_I: '> ',
            PROMPT_S: '> ',
            PROMPT_C: '> ',
            PROMPT_N: '> '
          }
        },
        PROMPT_MODE: :DEFAULT,
        MEASURE: true,
        MEASURE_PROC: { CUSTOM: measuring_proc }
      }

      out, err = execute_lines(
        "3\n",
        "measure :off\n",
        "3\n",
        conf: conf,
      )
      assert_empty err
      assert_match(/\Acustom processing time: .+\n=> 3\n=> nil\n=> 3\n/, out)
    end

    def test_measure_with_custom
      measuring_proc = proc { |line, line_no, &block|
        time = Time.now
        result = block.()
        puts 'custom processing time: %fs' % (Time.now - time) if IRB.conf[:MEASURE]
        result
      }
      conf = {
        PROMPT: {
          DEFAULT: {
            PROMPT_I: '> ',
            PROMPT_S: '> ',
            PROMPT_C: '> ',
            PROMPT_N: '> '
          }
        },
        PROMPT_MODE: :DEFAULT,
        MEASURE: false,
        MEASURE_PROC: { CUSTOM: measuring_proc }
      }
      out, err = execute_lines(
        "3\n",
        "measure\n",
        "3\n",
        "measure :off\n",
        "3\n",
        conf: conf
      )

      assert_empty err
      assert_match(/\A=> 3\nCUSTOM is added\.\n=> nil\ncustom processing time: .+\n=> 3\n=> nil\n=> 3\n/, out)
    end

    def test_measure_with_proc
      conf = {
        PROMPT: {
          DEFAULT: {
            PROMPT_I: '> ',
            PROMPT_S: '> ',
            PROMPT_C: '> ',
            PROMPT_N: '> '
          }
        },
        PROMPT_MODE: :DEFAULT,
        MEASURE: false,
      }
      c = Class.new(Object)
      out, err = execute_lines(
        "3\n",
        "measure { |context, code, line_no, &block|\n",
        "  result = block.()\n",
        "  puts 'aaa' if IRB.conf[:MEASURE]\n",
        "  result\n",
        "}\n",
        "3\n",
        "measure { |context, code, line_no, &block|\n",
        "  result = block.()\n",
        "  puts 'bbb' if IRB.conf[:MEASURE]\n",
        "  result\n",
        "}\n",
        "3\n",
        "measure :off\n",
        "3\n",
        conf: conf,
        main: c
      )

      assert_empty err
      assert_match(/\A=> 3\nBLOCK is added\.\n=> nil\naaa\n=> 3\nBLOCK is added.\naaa\n=> nil\nbbb\n=> 3\n=> nil\n=> 3\n/, out)
      assert_empty(c.class_variables)
    end
  end

end
