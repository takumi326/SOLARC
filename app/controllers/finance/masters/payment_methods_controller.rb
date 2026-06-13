# frozen_string_literal: true

module Finance
  module Masters
    class PaymentMethodsController < ApplicationController
      def new
        @payment_method = PaymentMethod.new(method_type: :card, ledger_charge_timing: :next_month)
      end

      def create
        @payment_method = PaymentMethod.new(payment_method_params)
        if @payment_method.save
          redirect_to finance_masters_path(tab: "payments"), notice: "支払方法を追加しました。"
        else
          flash.now[:alert] = @payment_method.errors.full_messages.join(" ")
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @payment_method = PaymentMethod.find(params[:id])
      end

      def update
        @payment_method = PaymentMethod.find(params[:id])
        if @payment_method.update(payment_method_params)
          redirect_to finance_masters_path(tab: "payments"), notice: "支払方法を更新しました。"
        else
          flash.now[:alert] = @payment_method.errors.full_messages.join(" ")
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        payment_method = PaymentMethod.find(params[:id])
        payment_method.destroy!
        redirect_to finance_masters_path(tab: "payments"), notice: "支払方法を削除しました。"
      rescue ActiveRecord::DeleteRestrictionError
        redirect_to finance_masters_path(tab: "payments"), alert: "支出が紐づいているため削除できません。"
      end

      private

      def payment_method_params
        params.expect(payment_method: [ :name, :method_type, :closing_day, :debit_day, :ledger_charge_timing ])
      end
    end
  end
end
