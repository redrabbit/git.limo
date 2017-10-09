alias GitGud.Repo
alias GitGud.User
alias GitGud.Repository

u = Repo.insert!(%User{username: "redrabbit", name: "Mario Flach", email: "m.flach@almightycouch.com"})
r = Repo.insert!(%Repository{owner: u, path: "gitgud", name: "GitGud", description: "Git gud or git rekt!"})
IO.inspect r
