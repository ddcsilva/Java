CREATE TABLE order_items (
    id              BIGSERIAL       PRIMARY KEY,
    order_id        BIGINT          NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id    BIGINT          NOT NULL,
    menu_item_name  VARCHAR(255)    NOT NULL,
    quantity        INTEGER         NOT NULL CHECK (quantity > 0),
    unit_price      DECIMAL(10,2)   NOT NULL CHECK (unit_price > 0),
    subtotal        DECIMAL(10,2)   NOT NULL
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
