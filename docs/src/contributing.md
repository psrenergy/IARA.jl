# Contributing

We welcome contributions to the project.

# Code of Conduct

Please refer to the [Code of Conduct](https://github.com/psrenergy/IARA.jl/blob/main/CODE_OF_CONDUCT.md) for guidelines on how to interact with the community.


# Improve the documentation

The documentation is written in Markdown using [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) and [Literate.jl](https://github.com/fredrikekre/Literate.jl).
The source code for the documentation can be found [here](https://github.com/psrenergy/IARA.jl/tree/main/docs).

In order to submit a documentation change, you need to open a pull request (PR) to the `main` branch of the repository. Please follow the [Contribute code to IARA.jl](#contribute-code-to-iara-jl) section below for instructions on how to do this.



# File a bug report or feature request

If you encounter a bug or have a feature request, please file an issue on our [GitHub Issues page](https://github.com/psrenergy/IARA.jl/issues). 

When filing a bug report, please include:
- A clear and descriptive title.
- Steps to reproduce the issue.
- The expected behavior and what actually happens.
- Any relevant error messages or stack traces.
- Your Julia version and operating system details.

Providing this information will help us address the issue more efficiently. Thank you for your feedback!


# Contribute code to IARA.jl

If you do not have any experience with Git, GitHub, and Julia development, we recommend that you start by reading the following resources:
- [GitHub Guides](https://guides.github.com/activities/hello-world/)
- [Git and GitHub](https://try.github.io/)
- [Git](https://git-scm.com/book/en/v2)
- [Julia package development](https://docs.julialang.org/en/v1/stdlib/Pkg/#Developing-packages-1)


If you are already familiar with Git and GitHub, you can skip the above resources and follow these steps to contribute code to IARA.jl:

### Step 1: Choose an open issue

You can find our list of open issues [here](https://github.com/psrenergy/IARA.jl/issues). 

If you find an issue that you would like to work on, please comment on the issue to let us know that you are working on it and what you are planning to do. This will help us avoid duplicate work and keep everyone informed about the progress of the issue.

### Step 2: Fork the repository

Go to the [repository page](https://github.com/psrenergy/IARA.jl) and click the "Fork" button in the top right corner. This will create a copy of the repository in your GitHub account.

### Step 3: Clone the forked repository

Clone the repository to your local machine using your preferred Git client or the command line. For example, using the command line, you can run:

```bash
git clone https://github.com/psrenergy/IARA.jl.git
```
This will create a local copy of the repository in a folder named `IARA.jl`. 

### Step 4: Create a new branch

Navigate to the cloned repository folder and create a new branch for your changes. Use a descriptive name for the branch that reflects the issue you are working on. 

When creating a new branch, it is a good practice to use your initials and a short description of the issue. For example, if your name is John Doe and you are fixing an error in tests, you could name your branch `jd/fix-tests`. This helps to keep the branch names organized and makes it easier to identify the purpose of each branch.

```bash
cd IARA.jl
git checkout -b jd/fix-tests
```

### Step 5: Make your changes

Make the necessary changes to the codebase. Be sure to follow the project's [coding style and conventions](./style_guide.md).
If you are adding new features or making significant changes, consider writing tests to ensure that your changes work as expected. You can find the tests in the `test` folder of the repository.

### Step 6: Test your changes

Run the tests to ensure that everything is working correctly. You can run the tests using the following command in the terminal:

```bash
julia --project

] test
```

### Step 7: Commit your changes

Once you are satisfied with your changes, commit them to your branch. Use a clear and descriptive commit message that explains what you have done. For example:

```bash
git add .
git commit -m "Fix tests for IARA.jl"
```

### Step 8: Push your changes

Push your changes to your forked repository on GitHub:

```bash
git push origin jd/fix-tests
```

This will upload your changes to the branch you created in your forked repository.

### Step 9: Create a pull request

Once you have pushed your changes, go to the original repository (not your fork) and click on the "Pull requests" tab. Click the "New pull request" button.
Select your branch from the dropdown menu and click "Create pull request".

Add a title and description for your pull request, explaining what changes you made and why. This will help the maintainers understand your changes and review them more efficiently.

### Step 10: Address feedback

If the maintainers request changes or provide feedback on your pull request, make the necessary updates to your branch. You can do this by editing the files locally, committing the changes, and pushing them to the same branch:

```bash
git add .
git commit -m "Address feedback on pull request"
git push origin jd/fix-tests
```

The pull request will automatically update with your new changes. Continue this process until the maintainers approve your pull request.

Once your pull request is approved and merged, you can delete your branch both locally and on GitHub to keep your workspace clean:

```bash
git branch -d jd/fix-tests
git push origin --delete jd/fix-tests
```

Thank you for contributing to IARA.jl!