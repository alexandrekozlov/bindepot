defmodule BindepotWeb.RepositoryLiveTest do
  use BindepotWeb.ConnCase

  import Phoenix.LiveViewTest
  import Bindepot.RepositoriesFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}
  defp create_repository(_) do
    repository = repository_fixture()

    %{repository: repository}
  end

  describe "Index" do
    setup [:create_repository]

    test "lists all repositories", %{conn: conn, repository: repository} do
      {:ok, _index_live, html} = live(conn, ~p"/ui/repositories")

      assert html =~ "Listing Repositories"
      assert html =~ repository.name
    end

    test "saves new repository", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/ui/repositories")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Repository")
               |> render_click()
               |> follow_redirect(conn, ~p"/ui/repositories/new")

      assert render(form_live) =~ "New Repository"

      assert form_live
             |> form("#repository-form", repository: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#repository-form", repository: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/ui/repositories")

      html = render(index_live)
      assert html =~ "Repository created successfully"
      assert html =~ "some name"
    end

    test "updates repository in listing", %{conn: conn, repository: repository} do
      {:ok, index_live, _html} = live(conn, ~p"/ui/repositories")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#repositories-#{repository.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/ui/repositories/#{repository}/edit")

      assert render(form_live) =~ "Edit Repository"

      assert form_live
             |> form("#repository-form", repository: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#repository-form", repository: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/ui/repositories")

      html = render(index_live)
      assert html =~ "Repository updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes repository in listing", %{conn: conn, repository: repository} do
      {:ok, index_live, _html} = live(conn, ~p"/ui/repositories")

      assert index_live |> element("#repositories-#{repository.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#repositories-#{repository.id}")
    end
  end

  describe "Show" do
    setup [:create_repository]

    test "displays repository", %{conn: conn, repository: repository} do
      {:ok, _show_live, html} = live(conn, ~p"/ui/repositories/#{repository}")

      assert html =~ "Show Repository"
      assert html =~ repository.name
    end

    test "updates repository and returns to show", %{conn: conn, repository: repository} do
      {:ok, show_live, _html} = live(conn, ~p"/ui/repositories/#{repository}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/ui/repositories/#{repository}/edit?return_to=show")

      assert render(form_live) =~ "Edit Repository"

      assert form_live
             |> form("#repository-form", repository: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#repository-form", repository: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/ui/repositories/#{repository}")

      html = render(show_live)
      assert html =~ "Repository updated successfully"
      assert html =~ "some updated name"
    end
  end
end
