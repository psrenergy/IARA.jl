db = IARA.load_study(PATH; read_only = false)

IARA.add_asset_owner!(
    db;
    label = "exclusive_for_thermal_unit",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

IARA.update_bidding_group_relation!(
    db,
    "bg_1";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "exclusive_for_thermal_unit",
)

IARA.close_study!(db)
