defmodule Exampple.TemplateTest do
  use ExUnit.Case
  doctest Exampple.Template
  doctest Exampple.Template.Interpolation

  describe "bulk actions" do
    setup do
      Exampple.Template.init()
    end

    test "put/1" do
      assert [] == Exampple.Template.all()
      data = [{"data1", "Text1"}, {"data2", "Text2"}]
      assert data == Enum.sort(Exampple.Template.put(data))
      assert "Text1" == Exampple.Template.get("data1")
      assert "Text2" == Exampple.Template.get("data2")
    end

    test "all/0" do
      assert [] == Exampple.Template.all()
      data = [{"data1", "Text1"}, {"data2", "Text2"}]
      assert data == Enum.sort(Exampple.Template.put(data))
      assert data == Enum.sort(Exampple.Template.all())
    end
  end
end
