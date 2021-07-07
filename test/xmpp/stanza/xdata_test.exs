defmodule Exampple.Xmpp.Stanza.XdataTest do
  use ExUnit.Case, async: false
  import Exampple.Xml.Xmlel, only: [sigil_x: 2]
  alias Exampple.Xmpp.Stanza.Xdata

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
    end
  end
end
