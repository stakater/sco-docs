# Projects

Projects are isolated environments within your organisation. Each project has its own network isolation, role-based access, and resource quota, and it is where you provision and run services.

In the console, **Projects** appears in the sidebar alongside your other resources.

---

## Viewing Projects

Select **Projects** in the sidebar to open the list of projects you have access to. Each row shows the project and its status. Select a project to open its detail page.

![The Projects list]({{ screenshot: project-list }})

---

## Creating a Project

If you have permission to create projects, the Projects section shows a **Create Project** action.

1. Select **Create Project**.
1. Give the project a name.
1. Set the project's network and quota, and grant access to users or groups.
1. Submit. The platform provisions the project, and you are taken to its detail page.

![The Create Project form]({{ screenshot: project-create }})

!!! note
    Creating projects is typically reserved for organisation administrators. If you do not see the **Create Project** action, you do not have permission — contact your organisation administrator.

For the full list of project parameters and a `kubectl`-based guide, see [Creating Projects](../cloud-user-guide/projects/creating-projects.md) and the [Create a Project](../how-to-guides/user/create-project.md) how-to guide.

---

## Choosing a Project When You Provision

Resources live inside a project. When you create a resource in the console, you choose which project to create it in — the form only offers the projects where you are allowed to create that resource. See [Working with Resources](resources.md).

---

## What's Next?

- [Working with Resources](resources.md) — Provision services into a project
- [Creating Projects](../cloud-user-guide/projects/creating-projects.md) — Parameters and quota profiles
- [Create a Project How-To](../how-to-guides/user/create-project.md) — Full reference
