# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: order.proto
"""Generated protocol buffer code."""
from google.protobuf.internal import builder as _builder
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x0border.proto\x12\x12\x63om.example.orders\"\xf3\x01\n\x05Order\x12\x10\n\x08order_id\x18\x01 \x01(\t\x12\x13\n\x0b\x63ustomer_id\x18\x02 \x01(\t\x12-\n\x05items\x18\x03 \x03(\x0b\x32\x1e.com.example.orders.Order.Item\x12\x14\n\x0ctotal_amount\x18\x04 \x01(\x01\x12\x10\n\x08\x63urrency\x18\x05 \x01(\t\x12\x17\n\x0forder_timestamp\x18\x06 \x01(\x03\x1aS\n\x04Item\x12\x0f\n\x07item_id\x18\x01 \x01(\t\x12\x14\n\x0cproduct_name\x18\x02 \x01(\t\x12\x10\n\x08quantity\x18\x03 \x01(\x05\x12\x12\n\nunit_price\x18\x04 \x01(\x01\x62\x06proto3')

_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, globals())
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'order_pb2', globals())
if _descriptor._USE_C_DESCRIPTORS == False:

  DESCRIPTOR._options = None
  _ORDER._serialized_start=36
  _ORDER._serialized_end=279
  _ORDER_ITEM._serialized_start=196
  _ORDER_ITEM._serialized_end=279
# @@protoc_insertion_point(module_scope)
