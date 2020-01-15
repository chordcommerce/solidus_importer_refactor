# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SolidusImporter::ProcessImport do
  subject(:described_instance) { described_class.new(import) }

  describe '#process' do
    subject(:described_method) { described_instance.process }

    let(:rows_count) { import.rows.size }

    before { allow(Spree::LogEntry).to receive(:create!) }

    context 'with a customers file' do
      let(:import) { create(:solidus_importer_import_customers) }

      it 'imports some customers' do
        expect { described_method }.to(
          change(import.reload, :state).from('created').to('completed')
          .and(change(Spree::User, :count).by(2))
        )
        expect(Spree::LogEntry).to have_received(:create!).exactly(rows_count).times
        import.destroy
      end
    end

    context 'with a products file' do
      let(:import) { create(:solidus_importer_import_products) }
      let(:shipping_category) { create(:shipping_category) }

      before { shipping_category }

      after { shipping_category.destroy }

      it 'imports some products' do
        expect { described_method }.to(
          change(import.reload, :state).from('created').to('failed')
          .and(change(Spree::Product, :count).by(1))
          .and(change(Spree::Variant, :count).by(3))
        )
        expect(Spree::LogEntry).to have_received(:create!).exactly(rows_count).times
        import.destroy
      end
    end

    context 'with a orders file' do
      let(:import) { create(:solidus_importer_import_orders) }
      let(:store) { create(:store) }

      before { store }

      after { store.destroy }

      it 'imports some orders' do
        expect { described_method }.to(
          change(import.reload, :state).from('created').to('completed')
          .and(change(Spree::Order, :count).by(2))
        )
        expect(Spree::LogEntry).to have_received(:create!).exactly(rows_count).times
      end
    end

    context 'with completed rows' do
      let(:process_row) { instance_double(::SolidusImporter::ProcessRow, process: nil) }
      let(:rows) { build_list(:solidus_importer_row_customer, 3) }
      let!(:import) { create(:solidus_importer_import_customers, rows: rows) }

      before do
        allow(::SolidusImporter::ProcessRow).to receive_messages(new: process_row)
        import.rows.first.update_column(:state, :completed)
        described_method
      end

      it { expect(::SolidusImporter::ProcessRow).to have_received(:new).exactly(rows_count - 1).times }
    end

    context 'with force_scan option' do
      subject(:described_method) { described_instance.process(force_scan: force_scan) }

      let(:force_scan) { true }
      let(:import) { create(:solidus_importer_import_customers) }

      before do
        allow(CSV).to receive(:parse).and_call_original
        described_method
      end

      it { expect(CSV).to have_received(:parse) }

      context 'without force_scan option' do
        let(:force_scan) { false }

        it { expect(CSV).not_to have_received(:parse) }
      end
    end
  end
end