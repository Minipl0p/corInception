DATA_DIR = /home/pchazalm/data

all:
	mkdir -p $(DATA_DIR)/mariadb
	mkdir -p $(DATA_DIR)/wordpress
	cd srcs && docker compose up --build -d

down:
	cd srcs && docker compose down

clean: down
	docker system prune -f

fclean: down
	docker system prune -af --volumes
	sudo rm -rf $(DATA_DIR)/mariadb
	sudo rm -rf $(DATA_DIR)/wordpress

re: fclean all

.PHONY: all down clean fclean re
