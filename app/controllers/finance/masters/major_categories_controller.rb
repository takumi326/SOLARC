# frozen_string_literal: true

module Finance
  module Masters
    class MajorCategoriesController < ApplicationController
      def new
        @major_category = MajorCategory.new(kind: params[:kind].presence_in(%w[expense income]) || "expense")
      end

      def create
        @major_category = MajorCategory.new(major_category_params)
        if @major_category.save
          redirect_to finance_masters_path(tab: "categories"), notice: "大カテゴリを追加しました。"
        else
          flash.now[:alert] = @major_category.errors.full_messages.join(" ")
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @major_category = MajorCategory.find(params[:id])
      end

      def update
        @major_category = MajorCategory.find(params[:id])
        if @major_category.update(major_category_params)
          redirect_to finance_masters_path(tab: "categories"), notice: "大カテゴリを更新しました。"
        else
          flash.now[:alert] = @major_category.errors.full_messages.join(" ")
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        major = MajorCategory.find(params[:id])
        major.destroy!
        redirect_to finance_masters_path(tab: "categories"), notice: "大カテゴリを削除しました。"
      rescue ActiveRecord::DeleteRestrictionError
        redirect_to finance_masters_path(tab: "categories"), alert: "小カテゴリが紐づいているため削除できません。"
      end

      private

      def major_category_params
        params.expect(major_category: [ :kind, :name ])
      end
    end
  end
end
