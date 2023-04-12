# setup with ansible

```sh
cd ansible
python3 -m venv venv
venv/bin/pip install -r requirements.freeze
```

# prepare

- Write `hosts.yml` .
    - SEE ALSO: `hosts.yml.example`

# run

```sh
source venv/bin/activate
ansible-playbook --check --inventory hosts.yml site.yml
ansible-playbook --inventory hosts.yml site.yml
```