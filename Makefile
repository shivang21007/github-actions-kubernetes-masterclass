CLUSTER  ?= skillpulse
NAMESPACE ?= skillpulse
BACKEND_IMAGE  ?= trainwithshubham/skillpulse-backend:latest
FRONTEND_IMAGE ?= trainwithshubham/skillpulse-frontend:latest

.PHONY: up down build load apply status logs mysql restart

INGRESS_NGINX_KIND ?= https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
# Must match k8s/kind-config.yaml extraPortMappings.containerPort (node side).
INGRESS_HTTP_HOSTPORT ?= 30060

up: ## One-shot: build images, create cluster, install ingress, load images, apply manifests
	$(MAKE) build
	kind create cluster --config k8s/kind-config.yaml --name $(CLUSTER)
	kubectl apply -f $(INGRESS_NGINX_KIND)
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=180s
	@echo "Patch ingress controller HTTP hostPort -> $(INGRESS_HTTP_HOSTPORT) (align with kind-config node port)"
	kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' \
		-p='[{"op": "replace", "path": "/spec/template/spec/containers/0/ports/0/hostPort", "value": $(INGRESS_HTTP_HOSTPORT)}]'
	kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s
	$(MAKE) load
	$(MAKE) apply
	@echo
	@echo "  SkillPulse is live at http://localhost:8060  (host 8060 → node 30060 → Ingress → frontend)"
	@echo

build: ## Build backend + frontend images for the host's architecture
	docker build -t $(BACKEND_IMAGE)  ./backend
	docker build -t $(FRONTEND_IMAGE) ./frontend

load: ## Push built images into the kind node
	kind load docker-image $(BACKEND_IMAGE)  --name $(CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE) --name $(CLUSTER)

apply: ## Apply manifests and wait for rollouts
	kubectl apply -f k8s/00-namespace.yaml \
	              -f k8s/10-mysql.yaml \
	              -f k8s/20-backend.yaml \
	              -f k8s/30-frontend.yaml \
	              -f k8s/35-hpa.yaml \
	              -f k8s/40-ingress.yaml
	kubectl rollout status statefulset/mysql    -n $(NAMESPACE) --timeout=180s
	kubectl rollout status deployment/backend   -n $(NAMESPACE) --timeout=120s
	kubectl rollout status deployment/frontend  -n $(NAMESPACE) --timeout=60s

down: ## Delete the cluster
	kind delete cluster --name $(CLUSTER)

status: ## Quick health snapshot
	@kubectl get pods,svc,ingress,endpoints -n $(NAMESPACE)

logs: ## Tail all three workloads at once
	@kubectl logs -n $(NAMESPACE) -l 'app in (mysql,backend,frontend)' --all-containers --tail=50 -f --max-log-requests=10

mysql: ## Open a mysql shell into the StatefulSet pod
	kubectl exec -it -n $(NAMESPACE) mysql-0 -- mysql -uskillpulse -pskillpulse123 skillpulse

restart: ## Rebuild + reload images, roll backend + frontend
	$(MAKE) build
	$(MAKE) load
	kubectl rollout restart deployment/backend deployment/frontend -n $(NAMESPACE)
	kubectl rollout status  deployment/backend  -n $(NAMESPACE) --timeout=120s
	kubectl rollout status  deployment/frontend -n $(NAMESPACE) --timeout=60s
