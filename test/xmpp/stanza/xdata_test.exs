defmodule Exampple.Xmpp.Stanza.XdataTest do
  use ExUnit.Case, async: false
  import Exampple.Xml.Xmlel, only: [sigil_x: 2]
  alias Exampple.Xmpp.Stanza.Xdata
  alias Exampple.Xmpp.Stanza.Xdata.FieldError

  describe "defining forms" do
    test "define normal form" do
      defmodule Form01 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("""
          Fill the whole form, please.
          """)

          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
        end
      end

      assert %{var: "name", type: "text-single", required: true} = Form01.get_field("name")
      assert %{options: [{"Male", "M"}, {"Female", "F"}]} = Form01.get_field("gender")
      assert [_FORM_TYPE, _name, _surname, _gender] = Form01.get_fields()
      assert "Fill the whole form, please.\n" = Form01.get_instructions()
      assert "Personal Details" = Form01.get_title()
    end

    test "type error" do
      assert_raise FieldError, fn ->
        defmodule Form02 do
          use Exampple.Xmpp.Stanza.Xdata

          form "", "" do
            field("name", :text, label: "Name")
          end
        end
      end
    end

    test "form error (missing FORM_TYPE)" do
      defmodule Form03 do
        use Exampple.Xmpp.Stanza.Xdata

        form "", "" do
          field("name", :text_single, label: "Name")
        end
      end

      form =
        Form03.new()
        |> Xdata.cast(%{"name" => "Manuel"})
        |> Xdata.validate_form()

      refute form.valid?

      assert [
               %{name: "form_type_missing", text: "FORM_TYPE is missing and is required"}
             ] == form.errors
    end

    test "form error (wrong FORM_TYPE)" do
      defmodule Form04 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:mydata", "My Data" do
          field("name", :text_single, label: "Name")
        end
      end

      form =
        Form04.new()
        |> Xdata.cast(%{"FORM_TYPE" => "urn:mydata:wrong", "name" => "Manuel"})
        |> Xdata.validate_form()

      refute form.valid?

      assert [
               %{
                 name: "form_type_not_matching",
                 text:
                   "FORM_TYPE urn:mydata:wrong != urn:mydata invalid for #{inspect(__MODULE__)}.Form04"
               }
             ] == form.errors
    end
  end

  describe "to string" do
    test "new directly to string" do
      defmodule Form11 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("Fill the whole form, please.")
          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
        end
      end

      xml =
        ~x[
      <x type='form' xmlns='jabber:x:data'>
        <title>Personal Details</title>
        <instructions>Fill the whole form, please.</instructions>
        <field var='FORM_TYPE' type='hidden'>
          <value>urn:xmpp:mydata</value>
        </field>
        <field label='Name' type='text-single' var='name'>
          <required/>
        </field>
        <field label='Surname' type='text-single' var='surname'/>
        <field label='Gender' type='list-single' var='gender'>
          <option label='Male'><value>M</value></option>
          <option label='Female'><value>F</value></option>
        </field>
      </x>
      ]
        |> to_string()

      assert xml == to_string(Form11.new())
    end
  end

  describe "cast and validation" do
    test "casting values" do
      defmodule Form21 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("Fill the whole form, please.")
          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
        end
      end

      form =
        Form21.new()
        |> Xdata.cast(%{
          "name" => "Manuel",
          "surname" => "Rubio",
          "gender" => "M",
          "age" => "41"
        })

      xml = ~x[
        <x type='form' xmlns='jabber:x:data'>
          <title>Personal Details</title>
          <instructions>Fill the whole form, please.</instructions>
          <field var='FORM_TYPE' type='hidden'>
            <value>urn:xmpp:mydata</value>
          </field>
          <field label='Name' type='text-single' var='name'>
            <required/>
            <value>Manuel</value>
          </field>
          <field label='Surname' type='text-single' var='surname'>
            <value>Rubio</value>
          </field>
          <field label='Gender' type='list-single' var='gender'>
            <value>M</value>
            <option label='Male'><value>M</value></option>
            <option label='Female'><value>F</value></option>
          </field>
        </x>
        ]

      assert is_nil(form.errors)
      assert form.valid?
      assert to_string(xml) == to_string(form)
    end

    test "don't use functions for literals" do
      assert_raise FieldError, fn ->
        defmodule Form26 do
          use Exampple.Xmpp.Stanza.Xdata

          def phone, do: "+31666555444"

          form "urn:xmpp:mydata", "Personal Details" do
            instructions("Fill the whole form, please.")
            field("name", :text_single, required: true, label: "Name", value: "John")
            field("surname", :text_single, label: "Surname", value: "Doe")
            field("phone", :text_single, value: phone())

            field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
          end
        end
      end
    end

    test "casting values in new function" do
      defmodule Form25 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("Fill the whole form, please.")
          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
        end
      end

      form =
        Form25.new("result", %{
          "name" => "Manuel",
          "surname" => "Rubio",
          "gender" => "M",
          "age" => "41"
        })

      xml = ~x[
        <x type='result' xmlns='jabber:x:data'>
          <title>Personal Details</title>
          <instructions>Fill the whole form, please.</instructions>
          <field var='FORM_TYPE' type='hidden'>
            <value>urn:xmpp:mydata</value>
          </field>
          <field label='Name' type='text-single' var='name'>
            <required/>
            <value>Manuel</value>
          </field>
          <field label='Surname' type='text-single' var='surname'>
            <value>Rubio</value>
          </field>
          <field label='Gender' type='list-single' var='gender'>
            <value>M</value>
            <option label='Male'><value>M</value></option>
            <option label='Female'><value>F</value></option>
          </field>
        </x>
        ]

      assert is_nil(form.errors)
      assert form.valid?
      assert to_string(xml) == to_string(form)
    end

    test "casting multi-values" do
      defmodule Form24 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("Fill the whole form, please.")
          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("emails", :text_multi, label: "Emails")

          field("countries", :list_multi,
            label: "Visited Countries",
            options: [
              {"Spain", "ES"},
              {"Netherlands", "NL"},
              {"United Kingdom", "UK"},
              {"Finland", "FI"},
              {"Sweden", "SE"},
              {"France", "FR"},
              {"Italy", "IT"},
              {"United States", "US"}
            ]
          )
        end
      end

      form =
        Form24.new()
        |> Xdata.cast(%{
          "name" => "Manuel",
          "surname" => ["Rubio", "Jimenez"],
          "emails" => [
            "manuel@altenwald.com",
            "info@altenwald.com",
            "marga@altenwald.com"
          ],
          "countries" => "NL",
          "age" => "41"
        })

      xml = ~x[
        <x type='form' xmlns='jabber:x:data'>
          <title>Personal Details</title>
          <instructions>Fill the whole form, please.</instructions>
          <field var='FORM_TYPE' type='hidden'>
            <value>urn:xmpp:mydata</value>
          </field>
          <field label='Name' type='text-single' var='name'>
            <required/>
            <value>Manuel</value>
          </field>
          <field label='Surname' type='text-single' var='surname'>
            <value>Rubio</value>
          </field>
          <field label='Emails' type='text-multi' var='emails'>
            <value>manuel@altenwald.com</value>
            <value>info@altenwald.com</value>
            <value>marga@altenwald.com</value>
          </field>
          <field label='Visited Countries' type='list-multi' var='countries'>
            <value>NL</value>
            <option label='Spain'><value>ES</value></option>
            <option label='Netherlands'><value>NL</value></option>
            <option label='United Kingdom'><value>UK</value></option>
            <option label='Finland'><value>FI</value></option>
            <option label='Sweden'><value>SE</value></option>
            <option label='France'><value>FR</value></option>
            <option label='Italy'><value>IT</value></option>
            <option label='United States'><value>US</value></option>
          </field>
        </x>
        ]

      assert is_nil(form.errors)
      assert form.valid?
      assert to_string(xml) == to_string(form)
    end

    test "submit a form" do
      defmodule Form22 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("Fill the whole form, please.")
          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
        end
      end

      form =
        Form22.new()
        |> Xdata.submit(%{
          "name" => "Manuel",
          "surname" => "Rubio",
          "gender" => "M",
          "age" => "41"
        })

      xml = ~x[
        <x type='submit' xmlns='jabber:x:data'>
          <title>Personal Details</title>
          <instructions>Fill the whole form, please.</instructions>
          <field var='FORM_TYPE' type='hidden'>
            <value>urn:xmpp:mydata</value>
          </field>
          <field label='Name' type='text-single' var='name'>
            <required/>
            <value>Manuel</value>
          </field>
          <field label='Surname' type='text-single' var='surname'>
            <value>Rubio</value>
          </field>
          <field label='Gender' type='list-single' var='gender'>
            <value>M</value>
            <option label='Male'><value>M</value></option>
            <option label='Female'><value>F</value></option>
          </field>
        </x>
        ]

      assert nil == form.errors
      assert form.valid?
      assert to_string(xml) == to_string(form)

      result_form = Xdata.submit(form, %{})

      result_xml = ~x[
        <x type='result' xmlns='jabber:x:data'>
          <title>Personal Details</title>
          <instructions>Fill the whole form, please.</instructions>
          <field var='FORM_TYPE' type='hidden'>
            <value>urn:xmpp:mydata</value>
          </field>
          <field label='Name' type='text-single' var='name'>
            <required/>
            <value>Manuel</value>
          </field>
          <field label='Surname' type='text-single' var='surname'>
            <value>Rubio</value>
          </field>
          <field label='Gender' type='list-single' var='gender'>
            <value>M</value>
            <option label='Male'><value>M</value></option>
            <option label='Female'><value>F</value></option>
          </field>
        </x>
        ]

      assert nil == result_form.errors
      assert result_form.valid?
      assert to_string(result_xml) == to_string(result_form)
    end

    test "validation errors" do
      defmodule Form23 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("Fill the whole form, please.")
          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
        end
      end

      form =
        Form23.new()
        |> Xdata.cast(%{
          "surname" => "Rubio",
          "gender" => "X"
        })
        |> Xdata.validate_form()

      assert [
               %{name: "required", text: "name is required"},
               %{name: "invalid-option", text: "gender use invalid option `X`"}
             ] = form.errors

      refute form.valid?

      form =
        Form23.new()
        |> Xdata.cast(%{
          "surname" => "Rubio",
          "gender" => ""
        })
        |> Xdata.validate_form()

      assert [
               %{name: "required", text: "name is required"},
               %{name: "invalid-option", text: "gender use invalid empty option"}
             ] = form.errors

      refute form.valid?
    end
  end

  describe "parsing" do
    test "parsing from binary" do
      defmodule Form31 do
        use Exampple.Xmpp.Stanza.Xdata

        form "urn:xmpp:mydata", "Personal Details" do
          instructions("Fill the whole form, please.")
          field("name", :text_single, required: true, label: "Name")
          field("surname", :text_single, label: "Surname")

          field("gender", :list_single, label: "Gender", options: [{"Male", "M"}, {"Female", "F"}])
        end
      end

      xml =
        ~x[
      <x type='form' xmlns='jabber:x:data'>
        <title>Personal Details</title>
        <instructions>Fill the whole form, please.</instructions>
        <field var='FORM_TYPE' type='hidden'>
          <value>urn:xmpp:mydata</value>
        </field>
        <field label='Name' type='text-single' var='name'>
          <required/>
        </field>
        <field label='Surname' type='text-single' var='surname'/>
        <field label='Gender' type='list-single' var='gender'>
          <option label='Male'><value>M</value></option>
          <option label='Female'><value>F</value></option>
        </field>
      </x>
      ]
        |> to_string()

      assert %Xdata{
               data: %{
                 "FORM_TYPE" => "urn:xmpp:mydata",
                 "gender" => nil,
                 "name" => nil,
                 "surname" => nil
               },
               module: Form31,
               xdata_form_type: "form"
             } == Form31.parse(xml)
    end
  end
end
