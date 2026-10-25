# 0020 — The public repository starts with one commit, and the plans live in a private repository

## Context

This repository was private before its public launch, at version 0.1.0 of the
standing-documents guide. Two parts of it held private content:

1. **The plan documents, in a directory under `docs/`.** They described the maintainer's
   private projects. No installed plugin reads a plan. A plan is a record for the maintainer.
2. **The git history.** It held each earlier version of the plans, and of the ADRs that named
   private projects, their paths, and their commit SHAs. At the decision, the history had 330
   commits, and 63 commit messages named the maintainer or a private project.

A commit that deletes a file does not hide the file, because each earlier commit still holds it.
On GitHub, a history rewrite and a force-push do not hide it either. GitHub keeps each pull
request's commits under `refs/pull/N/head`, and a push cannot change a ref that starts with
`refs/pull/`. GitHub also keeps each pull request's description and comments. Only GitHub
Support can remove that content.[^github] The repository had 36 pull requests.

## Decision

**The public repository is a new GitHub repository, and it starts with one commit.** That
commit holds the tree as it was at the launch, with no earlier history. The old repository
stays private, as an archive. It holds the full history, the pull requests, and the reasons that
the old commit messages give.

**The plans live in a private repository, outside this one.** This repository keeps no plans.
The maintainer's plan-directory map for the `dev-workflow:write-plan` skill names that private
repository, so each new plan goes there.

**So no earlier commit resolves in this repository.** Before the launch, ADRs 0001, 0002, 0004,
0005, and 0018 cited six commit SHAs of this repository. None of them resolves in the public
repository. This is the evidence for the rule in `docs/adr/README.md` that an ADR cites no
commit SHA.

A file that the earlier history deleted is absent from this repository too, so
`git log --diff-filter=D -- <path>` finds it in the archive only. ADR 0003 names such a path,
`plugins/<plugin>/PROVENANCE.md`, and ADR 0018 names the paths of ADRs 0012 to 0016. Also,
`git blame` in this repository starts at the first commit.

## The alternatives that lost

**A rewritten history, with `git filter-repo`.** The rewrite removes the plans from every
commit, and it replaces each private name in each file and each commit message. The
replacement does not read the text. A sentence about what a private project showed becomes a
sentence about a name that means nothing. Each earlier version of each file needs the scrub,
and one missed string is public from then on. Someone also reads the 63 commit messages before
the push. The rewrite still needs a new GitHub repository, because of the pull request refs.

The value of the history is the reason for each change. The ADRs keep the reasons that a reader
needs, and the archive keeps the rest.

**Two repositories, with an export.** The private repository stays the working repository, and
a script copies the public files into a second repository. Each change then needs a sync step,
for as long as the repository exists. An edit in the public repository, such as a
contributor's pull request, goes back to the private repository by hand.

**A private git submodule for the plans.** Git hides the content of the submodule from the
public. But each public clone shows a broken submodule, and each change to a plan needs two
commits, one in each repository.

[^github]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
